# Services with files: where they run, and moving them

How the services tied to files (PrivateBin, Send, Audiobookshelf, Baikal, Headscale, legacy-web, Gitea, and the game worlds: Minecraft HC, Skyblock, Hytale) move between fuji and the thinkcentre. The design is in [decisions.md](../decisions.md) (6 Oct, "Services with files fail over by themselves"); the code is dotfiles `modules/nixos/site-failover/` and `modules/nixos/standby-copy.nix`; the rehearsal is dotfiles `tests/site-failover.nix`.

Nothing here needs doing by hand for a failover. This is for checking, and for the rare deliberate move.

## Where does a service run?

The node with the label `ha.radunenu.com/<service>=active` runs it:

```sh
kubectl get nodes -L ha.radunenu.com/privatebin,ha.radunenu.com/send-uploads,ha.radunenu.com/audiobookshelf,ha.radunenu.com/baikal,ha.radunenu.com/headscale,ha.radunenu.com/legacy-web,ha.radunenu.com/gitea,ha.radunenu.com/minecraft-hc,ha.radunenu.com/minecraft-skyblock,ha.radunenu.com/hytale
```

On fuji or the thinkcentre, the site-failover daemon's own view (cluster reachable, label here, a whole copy here, who holds the label) is in `journalctl -u site-failover` and on its local status page (the port is in the module).

The service's folder on the active node is `/srv/ha/<service>`. On the other node that path doesn't exist, on purpose: nothing can run there by mistake.

## What happens on its own

- **The active node dies:** about a minute after the cluster marks it not ready, the other node takes the label, if a whole copy has arrived there before. The service starts on the copy; files written since the last copy (at most 10 minutes) are lost.
- **The active node is cut off but alive:** after 45 seconds without the cluster it kills the service's container and removes `/srv/ha/<service>`. The other site takes over afterwards, never at the same time.
- **The old node comes back:** it stays the standby. The copies now go the other way and overwrite its old folder.

The service doesn't move back by itself. That's deliberate: no second outage.

## Moving a service on purpose

For example to put it back on its usual node after a failover. Only with both nodes up, and at a quiet moment:

1. On the active node, `systemctl start standby-copy-<service>` and check it succeeded.
2. Right after, move the label: `kubectl label node <active> ha.radunenu.com/<service>-` then `kubectl label node <other> ha.radunenu.com/<service>=active`. The old node stops the service within seconds (its fence).
3. Delete the service's pod (`kubectl -n <namespace> delete pod -l <its labels>`). With both nodes up, nothing evicts it by itself; its replacement starts on the other node.

Whatever was written in the seconds between the copy and the move is lost. (Scaling the Deployment down first doesn't work: Argo puts it straight back.)

## Alerts

- `StandbyCopyStale`: a copy hasn't succeeded for an hour. After a failover this is expected until the old node is back (there's nowhere to copy to).

## Game servers

The game relay (dotfiles `modules/nixos/game-relay.nix`, on fuji and the edge) sends each game's port to whichever node holds the game's label, asking the site-failover status pages every 10 seconds. Minecraft's copies save over RCON first and turn saving off while copying (saving is back on right after, whatever happens to the copy). A copy's log shows "Automatic saving is now disabled" and "...enabled" around it.
