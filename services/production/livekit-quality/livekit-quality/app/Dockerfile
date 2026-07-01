# Build a static-ish binary for the quality exporter.
# `go mod tidy` runs here so the image build is the thing that resolves and
# verifies the LiveKit SDK versions — a clear failure point if the API drifts.
FROM golang:1.26-bookworm AS build
WORKDIR /src
COPY go.mod ./
COPY main.go ./
RUN go mod tidy
RUN CGO_ENABLED=0 GOFLAGS=-mod=mod go build -trimpath -ldflags="-s -w" -o /out/exporter .

FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=build /out/exporter /exporter
EXPOSE 6790
USER nonroot:nonroot
ENTRYPOINT ["/exporter"]
