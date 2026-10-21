#!/usr/bin/env python3
"""Builds kubernetes/argocd/outage-page-configmap.yaml from page.html.

    python3 kubernetes/argocd/outage-page/build.py --page <yeetus>/apps/outage/dist/index.html
    python3 kubernetes/argocd/outage-page/build.py          # again from page.html
    python3 kubernetes/argocd/outage-page/build.py --check  # CI: is it current?

The page is Yeetus's own (git.yeetus.net/radu/yeetus, apps/outage): the scene,
logo and colours for the time of day, season and holiday, built into one
self-contained file, since it's shown exactly when the rest of the network may
not answer. --page copies a new build in as page.html. Its double-brace
placeholders become nginx SSI here, which fills in each request's details.
"""

import pathlib
import re
import sys

HERE = pathlib.Path(__file__).resolve().parent
OUT = HERE.parent / "outage-page-configmap.yaml"

SSI = {
    "REQUEST_ID": '<!--# echo var="request_id" -->',
    "TIME": '<!--# echo var="date_gmt" -->',
    "HOST": '<!--# echo var="host" -->',
    "STATUS": '<!--# echo var="arg_status" -->',
    "NODE": '<!--# echo var="node" -->',
    "SITE": '<!--# echo var="site" -->',
    "URL": '<!--# echo var="arg_url" -->',
}

# nginx's official image runs envsubst on templates/*.template at start, for
# ${NODE_NAME} only (it leaves names that aren't in the environment alone).
NGINX = r"""# Built by outage-page/build.py; edit it there.
# Browsers get the page, anything else (Matrix and Git clients, CI runners) a
# line of JSON. Always 200: Traefik's errors middleware sends the visitor the
# original status (502-504) with this body.
map $http_accept $outage_html {
    default 0;
    "~*text/html" 1;
}
map $node $site {
    fuji ro;
    minima ro;
    thinkcentre dk;
    mixi dk;
    default "";
}
server {
    listen 8080;
    server_name _;
    root /page;
    set $node "${NODE_NAME}";

    ssi on;
    ssi_silent_errors on;
    ssi_last_modified off;

    add_header Cache-Control "no-store" always;
    add_header Retry-After "30" always;
    add_header X-Yeetus-Outage "1" always;
    add_header X-Request-Id $request_id always;

    location = /healthz {
        access_log off;
        default_type text/plain;
        return 200 "ok\n";
    }
    location / {
        default_type application/json;
        if ($outage_html = 0) {
            return 200 '{"error":"service_unavailable","message":"No working server right now; Yeetus Network is moving this service to a working copy by itself. Try again in a minute.","request_id":"$request_id"}\n';
        }
        try_files /index.html =404;
    }
    location = /index.html {
        default_type text/html;
    }
}
"""


def indent(text, n=4):
    pad = " " * n
    return "".join(pad + line if line.strip() else line for line in text.splitlines(True))


def build():
    page = (HERE / "page.html").read_text()
    for name, value in SSI.items():
        if name == "URL":
            continue
        token = "{{" + name + "}}"
        if token not in page:
            sys.exit(f"page.html has no {token}")
        page = page.replace(token, value)
    leftover = re.findall(r"\{\{[A-Z_]+\}\}", page)
    if leftover:
        sys.exit(f"page.html has placeholders build.py doesn't know: {leftover}")
    # SSI's date format, before anything is echoed.
    page = page.replace("<html", '<!--# config timefmt="%Y-%m-%d %H:%M:%S UTC" --><html', 1)
    return (
        "# Built by outage-page/build.py from page.html (Yeetus's apps/outage); don't edit by hand.\n"
        "apiVersion: v1\n"
        "kind: ConfigMap\n"
        "metadata:\n"
        "  name: outage-page\n"
        "  namespace: kube-system\n"
        "  annotations:\n"
        "    argocd.argoproj.io/sync-wave: \"-1\"\n"
        # Over the 256 KiB a client-side apply can keep in its annotation.
        "    argocd.argoproj.io/sync-options: ServerSideApply=true\n"
        "data:\n"
        "  index.html: |\n" + indent(page) +
        "  default.conf.template: |\n" + indent(NGINX)
    )


def main():
    if "--page" in sys.argv:
        src = pathlib.Path(sys.argv[sys.argv.index("--page") + 1])
        (HERE / "page.html").write_text(src.read_text())
    text = build()
    if "--check" in sys.argv:
        if not OUT.exists() or OUT.read_text() != text:
            sys.exit("kubernetes/argocd/outage-page-configmap.yaml is out of date: run kubernetes/argocd/outage-page/build.py")
        print("outage-page: outage-page-configmap.yaml is current")
        return
    OUT.write_text(text)
    print(f"wrote {OUT.relative_to(HERE.parent.parent.parent)} ({len(text) // 1024} KiB)")


if __name__ == "__main__":
    main()
