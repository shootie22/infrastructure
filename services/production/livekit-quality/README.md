# LiveKit Quality (per-participant)

Answers *who* is dropping packets on Element Call calls — by Matrix identity —
which the aggregate LiveKit metrics cannot.

LiveKit's Prometheus metrics (`livekit_packet_loss_percent`, `_rtt_ms`,
`_jitter_us`, …) are bucketed only by `direction`/`type`/`node_id`. They show the
SFU is losing packets but never whose. This stack closes that gap with two
layers:

1. **Log attribution** (wired elsewhere, see below) — which participant
   disconnected, the reason, and their real media IP.
2. **This stack** — a hidden probe that joins every active room and exports each
   participant's connection-quality score to Prometheus, labelled by identity.

## How the exporter works

`livekit-quality/app` is a small Go service. It polls `RoomService.ListRooms`
and, for each active room, joins as a **hidden, non-publishing, non-subscribing**
participant. LiveKit broadcasts a `ConnectionQualityUpdate` for *every*
participant to everyone in the room, so the probe observes them all and exports:

- `livekit_participant_quality_score{room, identity}` — 0 (lost) … 1 (excellent)
- `livekit_participant_quality{room, identity}` — enum as a number (0/1/2/3)
- `livekit_quality_probe_rooms_joined`

For Element Call the `identity` encodes the Matrix user/device — that is the
"who". The score is derived server-side from loss/jitter/RTT, so a participant
sitting consistently low is the one dropping; correlate the timestamp with the
log-attribution panels (below) to get their IP and the disconnect reason.

> Scope note: the probe gets per-participant **quality score**, not a raw
> per-person loss %. LiveKit only streams loss%/RTT to clients, not via the
> server API. The score singles out *who*; the raw % then comes from the
> aggregate `livekit_packet_loss_percent` panels + the debug logs.

## Architecture / tunnel

Mirrors the sibling `livekit-metrics` stack:

```
exporter (:6790, Hetzner) ── frpc ──► edge frps (:7198 → 127.0.0.1:5998)
                                        └─ monitoring_net alias livekit-quality-frps
Prometheus scrapes livekit-quality-frps:5998   (job: livekit-quality)
```

## Deploy

1. **LiveKit (`livekit.yaml`, Hetzner):** add a dedicated API key for the probe
   — do not reuse the Element Call app key:
   ```yaml
   keys:
     quality-probe: <generated-secret>
   ```
2. **Fill secrets:** edit `livekit-quality/runtime.env` (API key/secret, a fresh
   `FRP_TOKEN`) and `frps/runtime.env` (the same `FRP_TOKEN`). Then encrypt:
   ```bash
   scripts/encrypt-runtime-env      # generates age.pub + .env for each dir
   ```
3. **Edge host:** decrypt `frps/.env → frps/runtime.env`, then:
   ```bash
   cd frps && docker compose --env-file runtime.env up -d
   ```
4. **Hetzner host:** decrypt `livekit-quality/.env → runtime.env`, then:
   ```bash
   cd livekit-quality && docker compose --env-file runtime.env up -d --build
   ```
   (The image builds locally from `app/`; `go mod tidy` runs in the Dockerfile,
   so a LiveKit SDK API mismatch shows up as a clear build error.)

The Prometheus target (`grafana/prometheus/targets/livekit-quality.yml`) and job
are already committed; reload Prometheus to pick them up. The Grafana dashboard
row **"Per-participant quality (exporter)"** is already in `livekit.json`.

## Part 0 — Discovery (do once, for the log-attribution layer)

The log-attribution layer lives in two already-committed places:

- promtail: `services/production/hetzner-monitoring/.../promtail.yml` (`livekit`
  job) now extracts `participant`/`room`/`pID`/`reason` as structured metadata.
- dashboard: `livekit.json` row **"Per-participant attribution (logs)"**.

Both assume LiveKit's JSON log key names. `reason` is confirmed (the existing
Disconnect Reasons panel uses it); confirm the rest against real logs:

```bash
# On Hetzner, during a live call:
docker logs --since 10m element-call-livekit | tail -n 500
```

Check that participant identity is key `participant`, room is `room`, SID is
`pID`. If they differ, adjust the `json:` expressions in promtail.

**Client media IP + transport:** the SFU sees each friend's real public IP on the
selected ICE candidate pair (UDP, direct — not through Apache). That line is
usually emitted at **debug** level. To capture it for a debugging window, set
`log_level: debug` (or the rtc/transport logger) in `livekit.yaml`, restart, and
optionally enable the commented `drop` guard in promtail to keep Loki's ingest
budget (16 MB/s, 14d). The dashboard's **"ICE / candidate selection"** logs panel
surfaces those lines; read the IP/transport there. Once the exact field name is
known, the panel can become parsed columns.

## Part 3 — TURN (data-validated follow-up)

There is no TURN server today, so a friend behind a strict/symmetric NAT has no
relay fallback and their media can fail to establish or flap — a classic cause of
the disconnects this stack is meant to diagnose. **After** the dashboards are
live, watch for ICE failures / `tcp`+`relay` fallback / repeated reconnects
concentrated on specific friends. If that pattern appears, enable LiveKit's
built-in TURN in `livekit.yaml`:

```yaml
turn:
  enabled: true
  domain: <turn-domain>
  tls_port: 5349
```

…with a TLS cert and the relay ports opened on the Hetzner firewall. Framed as a
follow-up because the new dashboards will prove whether NAT/relay is the cause
before adding the service.

## Verification

- `curl -s 127.0.0.1:6790/metrics | grep livekit_participant_quality` on Hetzner
  shows a series per connected participant during a live call.
- Prometheus → target `livekit-quality` is `up`.
- Grafana → **Per-participant quality** graph populates; the worst friend visibly
  diverges. Correlate a dip with the **ICE / candidate selection** panel's IP and
  the **Disconnects by Participant** reason at the same timestamp.

### Troubleshooting

- **Probe joins rooms but no `quality_score` series appear.** The probe joins
  with `CanSubscribe=false` so it never pulls media (protects the home uplink).
  If a LiveKit version withholds `ConnectionQualityUpdate` from a non-subscriber,
  set `CanSubscribe` to `true` in `app/main.go` *and* pass
  `lksdk.WithAutoSubscribe(false)` to `ConnectToRoomWithToken` so it still pulls
  zero tracks. Rebuild.
- **Build fails on a callback signature.** The LiveKit Go SDK API occasionally
  moves `OnConnectionQualityChanged` between `RoomCallback` and
  `ParticipantCallback`, or renames a field — the build error points at the exact
  line; it is a one-line fix against the pinned `server-sdk-go/v2` version.
