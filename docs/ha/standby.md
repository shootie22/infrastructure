# Standbys

A standby is a workload that runs all the time but only takes traffic when its primary can't. LiveKit's edge SFU is the first: `livekit-edge` runs on the edge, and its `router` container is ready only while fuji's LiveKit is gone or calls are still on the edge (`matrix/livekit.yaml`, `ready.sh`). The `livekit` Service sends calls to whichever pod is ready.

So for a standby, readiness means "serving", not "healthy". Unready is its normal state, and anything that reads unready as broken is wrong about it.

## Marking one

On the Deployment:

```yaml
metadata:
  labels: {radunenu.com/role: standby}
spec:
  template:
    metadata:
      labels: {radunenu.com/role: standby}
      annotations:
        radunenu.com/serving-container: router
```

- `radunenu.com/role: standby` on the Deployment and its pods.
- `radunenu.com/serving-container`: the container whose readiness says whether it serves. Every other container's readiness is its health.

## What reads it

- **Alerts.** `KubernetesDeploymentReplicasUnavailable` leaves standbys out. `KubernetesStandbyUnhealthy` fires instead when a standby's pod isn't running, or a container other than the serving one isn't ready: it couldn't take over. Whether anything serves at all is the service's own alert (for calls, `MatrixCallsDown` and `MatrixCallsOnStandby`).
- **kube-state-metrics** exports the label and the annotation (`monitoring/workloads.yaml`), which is what the alerts join on.
- **Hub** shows a healthy standby as standby, not as a problem, and its pod as waiting rather than failed. It raises a problem when the standby is unhealthy by the same rule.
