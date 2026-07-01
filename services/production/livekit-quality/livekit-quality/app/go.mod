module livekit-quality-exporter

go 1.23

// Versions are resolved at image build time (`go mod tidy` in the Dockerfile).
// Pinned to recent, mutually compatible releases of the LiveKit Go SDK.
require (
	github.com/livekit/protocol v1.32.0
	github.com/livekit/server-sdk-go/v2 v2.4.0
	github.com/prometheus/client_golang v1.20.5
)
