# infrastructure

This repository holds the deployment configuration for my services and the shared config templates they use.

>**Note**: Migration of all my services over into this repository is in progress, as well as updating the information here.

## Repo model

This model will change, grow and adapt over time.

- `services/production/<stack>/` contains the deployable units for one stack.
- `services/testing/<stack>/` is the testing playground.
- `services/utils/` contains shared configurations used across services.

## Documentation

- [docs/infrastructure-topology.md](/home/krator/GitRepos/infrastructure/docs/infrastructure-topology.md) explains the edge and remote host model, monitoring flow, and deployment conventions.

## Security

#### Secrets
Secrets are stored in encrypted .env files using [SOPS](https://github.com/getsops/sops) & [AGE](https://github.com/FiloSottile/age) with per-deployment keys. My deployment automation decrypts secrets and passes them to docker-compose.

#### Tunnels
Each service is individually tunnelled through to my centralized edge ingress through [frp](https://github.com/fatedier/frp)/[rathole](https://github.com/rathole-org/rathole), each with its own set of tokens and sometimes TLS. On my edge node, Apache reverse proxies the service and serves it to the public.
>**Note**: In the future, I plan to migrate to [Traefik](https://traefik.io/traefik).
