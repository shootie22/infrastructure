FROM debian:bookworm-slim

ARG MTAIL_VERSION=3.0.8
ARG TARGETARCH

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl tar \
    && rm -rf /var/lib/apt/lists/*

RUN arch="${TARGETARCH:-amd64}" \
    && curl -fsSL -o /tmp/mtail.tar.gz "https://github.com/google/mtail/releases/download/v${MTAIL_VERSION}/mtail_${MTAIL_VERSION}_linux_${arch}.tar.gz" \
    && tar -xzf /tmp/mtail.tar.gz -C /usr/local/bin mtail \
    && rm /tmp/mtail.tar.gz

EXPOSE 3903

ENTRYPOINT ["/usr/local/bin/mtail"]
