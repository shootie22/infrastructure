module livekit-quality-exporter

go 1.26

// Versions are resolved at image build time (`go mod tidy` in the Dockerfile).
// Pinned to a coherent, current LiveKit Go SDK set — older mixes (e.g. v2.4.0)
// pulled transitive deps that disagreed on the gammazero/deque API.
require (
	github.com/livekit/protocol v1.48.2
	github.com/livekit/server-sdk-go/v2 v2.16.7
	github.com/prometheus/client_golang v1.23.2
)
