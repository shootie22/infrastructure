# Cubitrix

https://cubitrix.yeetus.net, the product page of
[Cubitrix](https://git.yeetus.net/radu/cubitrix), the Matrix app: what it
does, and the download buttons for each system.

The page is made in the Cubitrix repository, not here. Its CI
(`.gitea/workflows/site.yml`) fills the download section from the real
releases (newest version, date, size of each installer) when the page changes
and every six hours, then publishes the result to Gitea as the generic
package `cubitrix-site`, version `latest`, file `site.tar.gz`.

- `site.yaml`: Caddy's config, and `fetch.sh`, which checks Gitea for a newer
  page every five minutes, unpacks it beside the one being served and puts it
  in its place in one step. If Gitea can't be reached, or the package doesn't
  unpack, the page already here goes on being served.
- `deployment.yaml`: Caddy and fetch.sh in one pod, one copy per site. A pod
  is ready once its first fetch has finished.
- `networkpolicy.yaml`: the pods reach only DNS and Gitea.

## Changing the page

Change `site/` in the Cubitrix repository and push: CI publishes it, and both
copies serve it within five minutes. Nothing here changes.

After changing `site.yaml`, bump `config-revision` in `deployment.yaml` so the
pods restart and read it.

## By hand

    # What's being served, and when it last changed:
    kubectl -n cubitrix logs deploy/cubitrix -c fetch
