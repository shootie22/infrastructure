# Transitional external targets (not enabled)

These OVH-local FRP aliases are preserved for a later connectivity review. They are
not mounted by the K3s Prometheus and must not be enabled until their reachability
from K3s has been validated.

| Target | Job | Preserved labels |
| --- | --- | --- |
| `thinkcentre-frps:5994` | node-exporter | host=thinkcentre, site=homelab, role=workstation, os=linux |
| `thinkcentre-frps:5995` | cadvisor | host=thinkcentre, site=homelab, role=workstation, os=linux |
| `hetzner-frps:5991` | node-exporter | host=hetzner, site=hetzner, role=app-host, os=linux |
| `hetzner-frps:5992` | cadvisor | host=hetzner, site=hetzner, role=app-host, os=linux |
| `hetzner-frps:5993` | http-servers | host=hetzner, site=hetzner, role=app-host, os=linux, service=nginx, webserver=nginx |
| `synapse-frps:5996` | synapse | host=hetzner, site=hetzner, role=matrix, service=synapse, stack=matrix, os=linux |
| `livekit-frps:5997` | livekit | host=livekit, site=external, role=rtc, os=linux, service=livekit |
| `livekit-quality-frps:5998` | livekit-quality | host=livekit, site=external, role=rtc, os=linux, service=livekit-quality |
