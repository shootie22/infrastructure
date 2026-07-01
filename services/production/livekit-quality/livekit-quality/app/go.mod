module livekit-quality-exporter

go 1.23

// Versions are resolved at image build time (`go mod tidy` in the Dockerfile).
// Pinned to recent, mutually compatible releases of the LiveKit Go SDK.
require (
	github.com/livekit/protocol v1.32.0
	github.com/livekit/server-sdk-go/v2 v2.4.0
	github.com/prometheus/client_golang v1.20.5
)

// livekit/mediatransportutil (pulled in transitively) calls deque.SetMinCapacity,
// which was removed in gammazero/deque v1.0.0 (renamed to SetBaseCap). Something
// else in the graph pulls deque v1.x, so MVS picks the incompatible version and
// the build fails. Force it back to the last release that still has the method.
replace github.com/gammazero/deque => github.com/gammazero/deque v0.2.1
