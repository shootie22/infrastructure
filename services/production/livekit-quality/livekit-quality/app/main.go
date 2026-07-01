// livekit-quality-exporter
//
// Joins every active LiveKit room as a hidden, non-publishing, non-subscribing
// participant and exports each *other* participant's connection-quality score
// (0 = lost … 1 = excellent) to Prometheus, labelled by room + identity.
//
// LiveKit's own Prometheus metrics are aggregate only (by direction/type/node),
// so they can tell you the SFU is losing packets but never *whose*. The server
// broadcasts a ConnectionQualityUpdate for every participant to everyone in the
// room, so a hidden probe participant can observe all of them. For Element Call
// the participant identity encodes the Matrix user/device — that is the "who".
//
// This is intentionally small. If the LiveKit Go SDK API has drifted, the
// compile error will be obvious and local to one of the callback signatures.
package main

import (
	"context"
	"log"
	"net/http"
	"os"
	"os/signal"
	"strings"
	"sync"
	"syscall"
	"time"

	"github.com/livekit/protocol/auth"
	"github.com/livekit/protocol/livekit"
	lksdk "github.com/livekit/server-sdk-go/v2"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

var (
	qualityScore = prometheus.NewGaugeVec(prometheus.GaugeOpts{
		Name: "livekit_participant_quality_score",
		Help: "Per-participant connection quality score (0=lost..1=excellent), observed by the hidden quality probe.",
	}, []string{"room", "identity"})

	qualityEnum = prometheus.NewGaugeVec(prometheus.GaugeOpts{
		Name: "livekit_participant_quality",
		Help: "Per-participant connection quality enum as a number (0=lost,1=poor,2=good,3=excellent).",
	}, []string{"room", "identity"})

	roomsJoined = prometheus.NewGauge(prometheus.GaugeOpts{
		Name: "livekit_quality_probe_rooms_joined",
		Help: "Number of rooms the quality probe is currently joined to.",
	})
)

func init() {
	prometheus.MustRegister(qualityScore, qualityEnum, roomsJoined)
}

func env(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}

// qualityToNumber maps the LiveKit enum to a stable numeric for graphing.
func qualityToNumber(q livekit.ConnectionQuality) float64 {
	switch q {
	case livekit.ConnectionQuality_LOST:
		return 0
	case livekit.ConnectionQuality_POOR:
		return 1
	case livekit.ConnectionQuality_GOOD:
		return 2
	case livekit.ConnectionQuality_EXCELLENT:
		return 3
	default:
		return -1
	}
}

// manager tracks one probe connection per active room.
type manager struct {
	wsURL     string
	apiKey    string
	apiSecret string
	identity  string

	roomClient *lksdk.RoomServiceClient

	mu    sync.Mutex
	rooms map[string]*lksdk.Room // roomName -> live probe connection
}

func (m *manager) reconcile(ctx context.Context) {
	resp, err := m.roomClient.ListRooms(ctx, &livekit.ListRoomsRequest{})
	if err != nil {
		log.Printf("ListRooms failed: %v", err)
		return
	}

	active := make(map[string]bool, len(resp.Rooms))
	for _, r := range resp.Rooms {
		// Only bother with rooms that have real participants (our hidden probe
		// is not counted toward NumParticipants).
		if r.NumParticipants == 0 {
			continue
		}
		active[r.Name] = true
		m.ensureJoined(r.Name)
	}

	// Leave rooms that are no longer active.
	m.mu.Lock()
	for name, room := range m.rooms {
		if !active[name] {
			log.Printf("room %q gone, disconnecting probe", name)
			room.Disconnect()
			delete(m.rooms, name)
			qualityScore.DeletePartialMatch(prometheus.Labels{"room": name})
			qualityEnum.DeletePartialMatch(prometheus.Labels{"room": name})
		}
	}
	roomsJoined.Set(float64(len(m.rooms)))
	m.mu.Unlock()
}

func (m *manager) ensureJoined(roomName string) {
	m.mu.Lock()
	_, exists := m.rooms[roomName]
	m.mu.Unlock()
	if exists {
		return
	}

	token, err := m.buildToken(roomName)
	if err != nil {
		log.Printf("token for room %q failed: %v", roomName, err)
		return
	}

	cb := &lksdk.RoomCallback{
		OnDisconnected: func() {
			log.Printf("probe disconnected from room %q", roomName)
			m.mu.Lock()
			delete(m.rooms, roomName)
			roomsJoined.Set(float64(len(m.rooms)))
			m.mu.Unlock()
			qualityScore.DeletePartialMatch(prometheus.Labels{"room": roomName})
			qualityEnum.DeletePartialMatch(prometheus.Labels{"room": roomName})
		},
		OnParticipantDisconnected: func(p *lksdk.RemoteParticipant) {
			qualityScore.DeleteLabelValues(roomName, p.Identity())
			qualityEnum.DeleteLabelValues(roomName, p.Identity())
		},
		ParticipantCallback: lksdk.ParticipantCallback{
			// LiveKit only sends ConnectionQualityUpdate for participants we are
			// subscribed to. Subscribe to each participant's AUDIO track (tiny,
			// and stays local to the Hetzner host) so the server reports their
			// quality; skip video so we don't pull camera/screen streams we
			// never decode. Fires for tracks that already exist when we join.
			OnTrackPublished: func(pub *lksdk.RemoteTrackPublication, rp *lksdk.RemoteParticipant) {
				if pub.Kind() != lksdk.TrackKindAudio {
					return
				}
				if err := pub.SetSubscribed(true); err != nil {
					log.Printf("subscribe to %s audio failed: %v", rp.Identity(), err)
				}
			},
			OnConnectionQualityChanged: func(info *livekit.ConnectionQualityInfo, p lksdk.Participant) {
				identity := p.Identity()
				if identity == "" || identity == m.identity {
					return
				}
				qualityScore.WithLabelValues(roomName, identity).Set(float64(info.Score))
				qualityEnum.WithLabelValues(roomName, identity).Set(qualityToNumber(info.Quality))
			},
		},
	}

	room, err := lksdk.ConnectToRoomWithToken(m.wsURL, token, cb, lksdk.WithAutoSubscribe(false))
	if err != nil {
		log.Printf("join room %q failed: %v", roomName, err)
		return
	}

	m.mu.Lock()
	// Guard against a concurrent reconcile having joined in the meantime.
	if _, raced := m.rooms[roomName]; raced {
		m.mu.Unlock()
		room.Disconnect()
		return
	}
	m.rooms[roomName] = room
	roomsJoined.Set(float64(len(m.rooms)))
	m.mu.Unlock()
	log.Printf("probe joined room %q", roomName)
}

func (m *manager) buildToken(roomName string) (string, error) {
	canPublish := false
	// Must be allowed to subscribe or LiveKit won't send this participant the
	// room's ConnectionQualityUpdate broadcasts. We pair this with
	// WithAutoSubscribe(false) at connect time so it subscribes to zero tracks
	// and pulls no media — permission without traffic.
	canSubscribe := true
	at := auth.NewAccessToken(m.apiKey, m.apiSecret)
	at.SetVideoGrant(&auth.VideoGrant{
		RoomJoin:     true,
		Room:         roomName,
		CanPublish:   &canPublish,
		CanSubscribe: &canSubscribe,
		Hidden:       true,
	}).SetIdentity(m.identity).SetValidFor(time.Hour)
	return at.ToJWT()
}

func (m *manager) shutdown() {
	m.mu.Lock()
	defer m.mu.Unlock()
	for name, room := range m.rooms {
		room.Disconnect()
		delete(m.rooms, name)
	}
}

func main() {
	wsURL := env("LIVEKIT_URL", "wss://ec.nuke.zip")
	apiKey := os.Getenv("LIVEKIT_API_KEY")
	apiSecret := os.Getenv("LIVEKIT_API_SECRET")
	listenAddr := env("LISTEN_ADDR", ":6790")
	identity := env("PROBE_IDENTITY", "quality-probe")

	if apiKey == "" || apiSecret == "" {
		log.Fatal("LIVEKIT_API_KEY and LIVEKIT_API_SECRET are required")
	}

	// RoomService is an HTTP API; derive its base from the ws URL.
	apiURL := strings.Replace(strings.Replace(wsURL, "wss://", "https://", 1), "ws://", "http://", 1)

	pollInterval := 10 * time.Second
	if d, err := time.ParseDuration(env("POLL_INTERVAL", "")); err == nil && d > 0 {
		pollInterval = d
	}

	m := &manager{
		wsURL:      wsURL,
		apiKey:     apiKey,
		apiSecret:  apiSecret,
		identity:   identity,
		roomClient: lksdk.NewRoomServiceClient(apiURL, apiKey, apiSecret),
		rooms:      make(map[string]*lksdk.Room),
	}

	mux := http.NewServeMux()
	mux.Handle("/metrics", promhttp.Handler())
	mux.HandleFunc("/healthz", func(w http.ResponseWriter, _ *http.Request) { w.Write([]byte("ok")) })
	srv := &http.Server{Addr: listenAddr, Handler: mux}
	go func() {
		log.Printf("metrics listening on %s", listenAddr)
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("http server: %v", err)
		}
	}()

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	ticker := time.NewTicker(pollInterval)
	defer ticker.Stop()

	sig := make(chan os.Signal, 1)
	signal.Notify(sig, syscall.SIGINT, syscall.SIGTERM)

	log.Printf("polling %s every %s as hidden identity %q", apiURL, pollInterval, identity)
	m.reconcile(ctx)
	for {
		select {
		case <-ticker.C:
			m.reconcile(ctx)
		case <-sig:
			log.Print("shutting down")
			m.shutdown()
			shutdownCtx, c := context.WithTimeout(context.Background(), 5*time.Second)
			defer c()
			srv.Shutdown(shutdownCtx)
			return
		}
	}
}
