#!/usr/bin/env python3
"""Generate the Git-managed Grafana dashboard ConfigMaps.

The Python standard library is the only dependency. Run this file from anywhere;
it always writes beside itself. Generated ConfigMaps are committed for Argo CD.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parent
PROM = {"type": "prometheus", "uid": "prometheus"}
LOKI = {"type": "loki", "uid": "loki"}
CORE_LINK = {
    "asDropdown": True,
    "icon": "external link",
    "includeVars": True,
    "keepTime": True,
    "tags": ["observability-core"],
    "targetBlank": False,
    "title": "Observability",
    "type": "dashboards",
}


def target(expr: str, ref: str = "A", legend: str = "", *, instant: bool = False,
           datasource: dict | None = None, fmt: str | None = None) -> dict:
    item = {
        "datasource": datasource or PROM,
        "editorMode": "code",
        "expr": expr,
        "legendFormat": legend,
        "range": not instant,
        "refId": ref,
    }
    if instant:
        item["instant"] = True
    if fmt:
        item["format"] = fmt
    return item


def log_target(expr: str, ref: str = "A", legend: str = "") -> dict:
    return {
        "datasource": LOKI,
        "editorMode": "code",
        "expr": expr,
        "legendFormat": legend,
        "queryType": "range",
        "refId": ref,
    }


def thresholds(warn: float | None = None, critical: float | None = None,
               *, base: str = "green", reverse: bool = False) -> dict:
    steps = [{"color": base, "value": None}]
    if reverse:
        if critical is not None:
            steps.append({"color": "orange", "value": critical})
        if warn is not None:
            steps.append({"color": "green", "value": warn})
    else:
        if warn is not None:
            steps.append({"color": "orange", "value": warn})
        if critical is not None:
            steps.append({"color": "red", "value": critical})
    return {"mode": "absolute", "steps": steps}


def panel(title: str, kind: str, x: int, y: int, w: int, h: int, targets: list[dict],
          *, datasource: dict | None = None, unit: str = "short", description: str = "",
          threshold: dict | None = None, links: list[dict] | None = None,
          decimals: int | None = None, min_value: float | None = None,
          max_value: float | None = None) -> dict:
    defaults: dict = {
        "color": {"mode": "palette-classic"},
        "custom": {},
        "mappings": [],
        "thresholds": threshold or thresholds(),
        "unit": unit,
    }
    if decimals is not None:
        defaults["decimals"] = decimals
    if min_value is not None:
        defaults["min"] = min_value
    if max_value is not None:
        defaults["max"] = max_value
    if links:
        defaults["links"] = links

    options: dict = {}
    if kind == "stat":
        options = {
            "colorMode": "background",
            "graphMode": "area",
            "justifyMode": "auto",
            "orientation": "auto",
            "reduceOptions": {"calcs": ["lastNotNull"], "fields": "", "values": False},
            "textMode": "auto",
            "wideLayout": True,
        }
        defaults["color"] = {"mode": "thresholds"}
    elif kind in ("timeseries", "bargauge", "gauge"):
        defaults["custom"] = {
            "axisCenteredZero": False,
            "axisColorMode": "text",
            "axisLabel": "",
            "axisPlacement": "auto",
            "barAlignment": 0,
            "drawStyle": "line",
            "fillOpacity": 12,
            "gradientMode": "none",
            "hideFrom": {"legend": False, "tooltip": False, "viz": False},
            "lineInterpolation": "linear",
            "lineWidth": 1,
            "pointSize": 4,
            "scaleDistribution": {"type": "linear"},
            "showPoints": "never",
            "spanNulls": False,
            "stacking": {"group": "A", "mode": "none"},
            "thresholdsStyle": {"mode": "off"},
        }
        options = {
            "legend": {"calcs": ["lastNotNull"], "displayMode": "table", "placement": "right", "showLegend": True},
            "tooltip": {"hideZeros": False, "mode": "multi", "sort": "desc"},
        }
        if kind == "bargauge":
            options = {"displayMode": "gradient", "minVizHeight": 10, "minVizWidth": 0,
                       "namePlacement": "auto", "orientation": "horizontal",
                       "reduceOptions": {"calcs": ["lastNotNull"], "fields": "", "values": False},
                       "showUnfilled": True, "sizing": "auto", "valueMode": "color"}
    elif kind == "table":
        options = {"cellHeight": "sm", "footer": {"countRows": False, "fields": "", "reducer": ["sum"], "show": False},
                   "showHeader": True, "sortBy": [{"desc": True, "displayName": "Value"}]}
    elif kind == "logs":
        defaults = {"custom": {}, "mappings": [], "thresholds": thresholds(), "unit": "short"}
        options = {"dedupStrategy": "none", "enableLogDetails": True, "prettifyLogMessage": False,
                   "showCommonLabels": False, "showLabels": False, "showTime": True,
                   "sortOrder": "Descending", "wrapLogMessage": True}

    result = {
        "datasource": datasource or PROM,
        "description": description,
        "fieldConfig": {"defaults": defaults, "overrides": []},
        "gridPos": {"h": h, "w": w, "x": x, "y": y},
        "id": 0,
        "options": options,
        "pluginVersion": "12.4.1",
        "targets": targets,
        "title": title,
        "type": kind,
    }
    if links:
        if kind == "logs":
            result["links"] = links
        else:
            result["fieldConfig"]["defaults"]["links"] = links
    return result


def row(title: str, y: int, *, collapsed: bool = False) -> dict:
    return {"collapsed": collapsed, "gridPos": {"h": 1, "w": 24, "x": 0, "y": y},
            "id": 0, "panels": [], "title": title, "type": "row"}


def prom_var(name: str, query: str, *, label: str | None = None, multi: bool = False,
             include_all: bool = False, current: str | None = None) -> dict:
    value = current if current is not None else ("$__all" if include_all else "")
    text = "All" if include_all and current is None else value
    return {
        "allValue": ".*" if include_all else None,
        "current": {"selected": bool(value), "text": text, "value": value},
        "datasource": PROM,
        "definition": query,
        "hide": 0,
        "includeAll": include_all,
        "label": label or name.title(),
        "multi": multi,
        "name": name,
        "options": [],
        "query": {"query": query, "refId": f"var-{name}"},
        "refresh": 2,
        "regex": "",
        "skipUrlSync": False,
        "sort": 1,
        "type": "query",
    }


def loki_var(name: str, query: str, *, label: str | None = None, multi: bool = False,
             include_all: bool = False) -> dict:
    result = prom_var(name, query, label=label, multi=multi, include_all=include_all)
    result["datasource"] = LOKI
    result["query"] = query
    if include_all and name == "namespace":
        result["allValue"] = ".+"
    return result


def text_var(name: str, value: str, label: str | None = None) -> dict:
    return {"current": {"selected": True, "text": value, "value": value}, "hide": 0,
            "label": label or name.title(), "name": name, "options": [], "query": value,
            "skipUrlSync": False, "type": "textbox"}


def dashboard(title: str, uid: str, panels: list[dict], variables: list[dict],
              *, tags: list[str] | None = None, time_from: str = "now-6h") -> dict:
    for number, item in enumerate(panels, 1):
        item["id"] = number
    return {
        "annotations": {"list": [{"builtIn": 1, "datasource": {"type": "grafana", "uid": "-- Grafana --"},
                                      "enable": True, "hide": True, "iconColor": "rgba(0, 211, 255, 1)",
                                      "name": "Annotations & Alerts", "type": "dashboard"}]},
        "editable": False,
        "fiscalYearStartMonth": 0,
        "graphTooltip": 1,
        "links": [CORE_LINK],
        "liveNow": False,
        "panels": panels,
        "refresh": "30s",
        "schemaVersion": 42,
        "tags": ["observability-core", *(tags or [])],
        "templating": {"list": variables},
        "time": {"from": time_from, "to": "now"},
        "timepicker": {"refresh_intervals": ["10s", "30s", "1m", "5m", "15m", "30m", "1h"]},
        "timezone": "browser",
        "title": title,
        "uid": uid,
        "version": 1,
        "weekStart": "monday",
    }


POD_LINK = [{
    "targetBlank": False,
    "title": "Open pod drilldown",
    "url": "/d/obs-pod?var-namespace=${__field.labels.namespace}&var-pod=${__field.labels.pod}&from=${__from}&to=${__to}",
}]

WORKLOAD_LINK = [{
    "targetBlank": False,
    "title": "Open Kubernetes Workloads",
    "url": "/d/obs-workloads?from=${__from}&to=${__to}",
}]


def readable_fields(panels: list[dict]) -> None:
    """Give scalar series and table values explicit names; preserve label columns."""
    for item in panels:
        if item["type"] == "stat":
            for query in item.get("targets", []):
                if not query.get("legendFormat"):
                    query["legendFormat"] = item["title"]
        if item["type"] == "table":
            overrides = item["fieldConfig"]["overrides"]
            for query in item["targets"]:
                name = query.get("legendFormat") or item["title"]
                if len(item["targets"]) > 1 and not query.get("legendFormat"):
                    name += " " + query["refId"]
                overrides.append({"matcher": {"id": "byName", "options": "Value #" + query["refId"]},
                                  "properties": [{"id": "displayName", "value": name}]})
            if len(item["targets"]) == 1:
                overrides.append({"matcher": {"id": "byName", "options": "Value"},
                                  "properties": [{"id": "displayName", "value": item["targets"][0].get("legendFormat") or item["title"]}]})
            overrides.append({"matcher": {"id": "byName", "options": "Time"},
                              "properties": [{"id": "custom.hidden", "value": True}]})
            item["options"].pop("sortBy", None)


def platform_overview() -> dict:
    p: list[dict] = [
        row("Immediate health", 0),
        panel("Node Readiness", "stat", 0, 1, 4, 4,
              [target('avg(kube_node_status_condition{job="kube-state-metrics",condition="Ready",status="true"})', instant=True)],
              unit="percentunit", min_value=0, max_value=1,
              threshold=thresholds(0.999, 0.9, base="red", reverse=True),
              description="Share of Kubernetes nodes reporting Ready; 100% is healthy."),
        panel("Nodes Not Ready", "stat", 4, 1, 4, 4,
              [target('sum(kube_node_status_condition{job="kube-state-metrics",condition="Ready",status="true"} == 0) or vector(0)', instant=True)],
              threshold=thresholds(1, 2), description="A non-zero value indicates Kubernetes node availability loss."),
        panel("Unavailable Workload Replicas", "stat", 8, 1, 4, 4,
              [target('sum(clamp_min(kube_deployment_spec_replicas{job="kube-state-metrics"} - kube_deployment_status_replicas_available{job="kube-state-metrics"}, 0)) + sum(clamp_min(kube_statefulset_replicas{job="kube-state-metrics"} - kube_statefulset_status_replicas_ready{job="kube-state-metrics"}, 0)) + sum(kube_daemonset_status_number_unavailable{job="kube-state-metrics"})', instant=True)],
              threshold=thresholds(1, 3), description="Desired replicas that are not currently available across Deployments, StatefulSets, and DaemonSets."),
        panel("Pods Not Ready", "stat", 12, 1, 4, 4,
              [target('sum((max by (namespace,pod) (kube_pod_status_ready{job="kube-state-metrics",condition="true"}) == 0) * on(namespace,pod) group_left() (max by(namespace,pod) (kube_pod_status_phase{job="kube-state-metrics",phase=~"Pending|Running"}) == 1)) or vector(0)', instant=True)],
              threshold=thresholds(1, 4), links=WORKLOAD_LINK, description="Pending or running pods whose Ready condition is false."),
        panel("Core Targets Down", "stat", 16, 1, 4, 4,
              [target('sum(up{job=~"prometheus|grafana|kubernetes-apiserver|kube-state-metrics|node-exporter|kubelet|kubelet-cadvisor|kubernetes-services"} == 0) or vector(0)', instant=True)],
              threshold=thresholds(1, 2), description="Failed scrapes for the core metrics and monitoring targets."),
        panel("Public Probes Failing", "stat", 20, 1, 4, 4,
              [target('sum(probe_success{job="blackbox-http"} == 0) or vector(0)', instant=True)],
              threshold=thresholds(1, 2), description="HTTP/TLS probes from Fuji. This is not an outside-in availability check."),
        row("Capacity and stability", 5),
        panel("Node CPU Usage", "timeseries", 0, 6, 12, 7,
              [target('1 - avg by (node) (rate(node_cpu_seconds_total{job="node-exporter",mode="idle"}[$__rate_interval]))', legend="{{node}}")],
              unit="percentunit", min_value=0, max_value=1, description="Busy CPU share. Utilization alone is diagnostic, not an incident."),
        panel("Node Memory Used", "timeseries", 12, 6, 12, 7,
              [target('1 - (node_memory_MemAvailable_bytes{job="node-exporter"} / node_memory_MemTotal_bytes{job="node-exporter"})', legend="{{node}}")],
              unit="percentunit", min_value=0, max_value=1),
        panel("Root Filesystem Free", "bargauge", 0, 13, 8, 6,
              [target('node_filesystem_avail_bytes{job="node-exporter",mountpoint="/",fstype!~"tmpfs|overlay|squashfs"} / node_filesystem_size_bytes{job="node-exporter",mountpoint="/",fstype!~"tmpfs|overlay|squashfs"}', legend="{{node}}", instant=True)],
              unit="percentunit", min_value=0, max_value=1,
              threshold=thresholds(0.15, 0.08, base="red", reverse=True), description="Actual free space on each node's root filesystem."),
        panel("Container Restarts (1h)", "bargauge", 8, 13, 8, 6,
              [target('topk(10, sum by (namespace,pod) (increase(kube_pod_container_status_restarts_total{job="kube-state-metrics"}[1h])) > 0)', legend="{{namespace}} / {{pod}}", instant=True)],
              threshold=thresholds(1, 3), links=POD_LINK, decimals=1, description="Recent restart growth; zero-valued pods are omitted by the visual ranking."),
        panel("Active Alerts", "table", 16, 13, 8, 6,
              [target('ALERTS{alertstate="firing"}', instant=True, fmt="table")],
              description="Firing Prometheus rules. An empty table is healthy; notification delivery is not configured."),
        row("User impact and recent evidence", 19),
        panel("Public Endpoint Reachability", "timeseries", 0, 20, 12, 7,
              [target('probe_success{job="blackbox-http"}', legend="{{instance}}")],
              min_value=0, max_value=1, threshold=thresholds(1, None, base="red", reverse=True), description="1 means DNS, connection, TLS and an accepted HTTP response succeeded from inside the cluster."),
        panel("HTTP Probe Duration", "timeseries", 12, 20, 12, 7,
              [target('probe_duration_seconds{job="blackbox-http"}', legend="{{instance}}")], unit="s"),
        panel("Recent Warning Kubernetes Events (empty is healthy)", "logs", 0, 27, 24, 8,
              [log_target('{job="kubernetes-events"} | logfmt | type="Warning"')], datasource=LOKI,
              description="Scheduling, image pull, probe, mount, eviction, and node warnings collected from the Kubernetes Events API."),
    ]
    host_panels = {item["title"]: item for item in nodes_dashboard()["panels"]}
    for item in p:
        source = {"Node CPU Usage": "CPU Utilization", "Node Memory Used": "Memory Used",
                  "Root Filesystem Free": "Root Free"}.get(item["title"])
        if source:
            expression = host_panels[source]["targets"][0]["expr"].replace("$node", ".*")
            if source == "Root Free":
                expression = expression.removeprefix("min(")[:-1]
            item["targets"][0]["expr"] = expression
        if item["title"] == "Active Alerts":
            item["targets"][0]["expr"] = 'max by(alertname,severity,namespace,pod,node,instance,job) (ALERTS{alertstate="firing"})'
            item["targets"][0]["legendFormat"] = "Firing"
        if item["title"] == "Container Restarts (1h)":
            item["title"] = "Container Restarts in Selected Range"
            item["targets"][0]["expr"] = item["targets"][0]["expr"].replace("[1h]", "[$__range]")
    p.extend([
        row("Identify the affected target and workload in the selected interval", 35),
        panel("Target Availability History", "timeseries", 0, 36, 12, 7,
              [target('min by(job,instance) (up)', legend="{{job}} / {{instance}}")], min_value=0, max_value=1,
              description="Named scrape targets; zero identifies which collector or service failed at the time of the incident."),
        panel("Kubernetes Node Conditions", "timeseries", 12, 36, 12, 7,
              [target('max by(node,condition) (kube_node_status_condition{job="kube-state-metrics",condition!="Ready",status="true"})', "A", "{{node}} / {{condition}}"),
               target('1 - max by(node) (kube_node_status_condition{job="kube-state-metrics",condition="Ready",status="true"})', "B", "{{node}} / NotReady")], min_value=0, max_value=1),
        panel("CPU by Workload", "timeseries", 0, 43, 12, 7,
              [target('namespace_workload:container_cpu_usage_seconds_total:sum_rate5m', legend="{{namespace}} / {{workload}} / {{workload_type}}")], unit="cores",
              description="Zoom a host CPU spike to compare workloads at the same time. Kubernetes only; external Docker attribution is in Nodes / Hosts."),
        panel("Unavailable Replicas by Workload", "timeseries", 12, 43, 12, 7,
              [target('clamp_min(kube_deployment_spec_replicas{job="kube-state-metrics"} - kube_deployment_status_replicas_available{job="kube-state-metrics"}, 0)', "A", "{{namespace}} / deployment / {{deployment}}"),
               target('clamp_min(kube_statefulset_replicas{job="kube-state-metrics"} - kube_statefulset_status_replicas_ready{job="kube-state-metrics"}, 0)', "B", "{{namespace}} / statefulset / {{statefulset}}"),
               target('kube_daemonset_status_number_unavailable{job="kube-state-metrics"}', "C", "{{namespace}} / daemonset / {{daemonset}}")], min_value=0),
        panel("Container Waiting Reasons", "timeseries", 0, 50, 12, 7,
              [target('max by(namespace,pod,container,reason) (kube_pod_container_status_waiting_reason{job="kube-state-metrics"}) == 1', legend="{{namespace}} / {{pod}} / {{container}} / {{reason}}")], links=POD_LINK, min_value=0, max_value=1),
        panel("Probe HTTP Response Status", "timeseries", 12, 50, 12, 7,
              [target('probe_http_status_code{job="blackbox-http"}', legend="{{instance}}")],
              description="HTTP status observed by the probe; zero can indicate failure before an HTTP response. Compare DNS/connect/TLS phases on Edge / Traefik."),
    ])
    readable_fields(p)
    return dashboard("Platform Overview", "obs-platform", p, [], tags=["overview"], time_from="now-3h")


def nodes_dashboard() -> dict:
    n = '$node'
    p = [
        row("Node state", 0),
        panel("Readiness", "stat", 0, 1, 4, 4, [target(f'avg(kube_node_status_condition{{job="kube-state-metrics",condition="Ready",status="true",node=~"{n}"}})', instant=True)],
              unit="percentunit", min_value=0, max_value=1,
              threshold=thresholds(0.999, 0.9, base="red", reverse=True),
              description="Share of selected nodes reporting Ready."),
        panel("Uptime", "stat", 4, 1, 5, 4, [target(f'min(time() - node_boot_time_seconds{{job="node-exporter",node=~"{n}"}})', instant=True)], unit="s"),
        panel("CPU Usage", "stat", 9, 1, 5, 4, [target(f'1 - avg(rate(node_cpu_seconds_total{{job="node-exporter",mode="idle",node=~"{n}"}}[5m]))', instant=True)], unit="percentunit", min_value=0, max_value=1),
        panel("Memory Used", "stat", 14, 1, 5, 4, [target(f'1 - sum(node_memory_MemAvailable_bytes{{job="node-exporter",node=~"{n}"}}) / sum(node_memory_MemTotal_bytes{{job="node-exporter",node=~"{n}"}})', instant=True)], unit="percentunit", min_value=0, max_value=1),
        panel("Root Free", "stat", 19, 1, 5, 4, [target(f'min(node_filesystem_avail_bytes{{job="node-exporter",node=~"{n}",mountpoint="/",fstype!~"tmpfs|overlay|squashfs"}} / node_filesystem_size_bytes{{job="node-exporter",node=~"{n}",mountpoint="/",fstype!~"tmpfs|overlay|squashfs"}})', instant=True)], unit="percentunit", min_value=0, max_value=1, threshold=thresholds(0.15, 0.08, base="red", reverse=True)),
        row("Compute pressure", 5),
        panel("CPU Utilization", "timeseries", 0, 6, 12, 7, [target(f'1 - avg by(node) (rate(node_cpu_seconds_total{{job="node-exporter",mode="idle",node=~"{n}"}}[$__rate_interval]))', legend="{{node}}")], unit="percentunit", min_value=0, max_value=1),
        panel("Load Relative to CPU Count", "timeseries", 12, 6, 12, 7, [target(f'node_load1{{job="node-exporter",node=~"{n}"}} / on(node) count by(node) (node_cpu_seconds_total{{job="node-exporter",mode="idle",node=~"{n}"}})', legend="{{node}}")], unit="percentunit", min_value=0, description="One-minute runnable load divided by logical CPU count; values over 1 indicate queueing."),
        panel("Memory Used", "timeseries", 0, 13, 12, 7, [target(f'1 - node_memory_MemAvailable_bytes{{job="node-exporter",node=~"{n}"}} / node_memory_MemTotal_bytes{{job="node-exporter",node=~"{n}"}}', legend="{{node}}")], unit="percentunit", min_value=0, max_value=1),
        panel("Swap Used", "timeseries", 12, 13, 12, 7, [target(f'(node_memory_SwapTotal_bytes{{job="node-exporter",node=~"{n}"}} - node_memory_SwapFree_bytes{{job="node-exporter",node=~"{n}"}}) / clamp_min(node_memory_SwapTotal_bytes{{job="node-exporter",node=~"{n}"}}, 1)', legend="{{node}}")], unit="percentunit", min_value=0, max_value=1),
        row("Storage and I/O", 20),
        panel("Filesystem Used", "timeseries", 0, 21, 12, 7, [target(f'1 - node_filesystem_avail_bytes{{job="node-exporter",node=~"{n}",fstype!~"tmpfs|overlay|squashfs|nsfs",mountpoint!~"/var/lib/kubelet/pods/.+"}} / node_filesystem_size_bytes{{job="node-exporter",node=~"{n}",fstype!~"tmpfs|overlay|squashfs|nsfs",mountpoint!~"/var/lib/kubelet/pods/.+"}}', legend="{{node}} {{mountpoint}}")], unit="percentunit", min_value=0, max_value=1),
        panel("Inodes Used", "timeseries", 12, 21, 12, 7, [target(f'1 - node_filesystem_files_free{{job="node-exporter",node=~"{n}",fstype!~"tmpfs|overlay|squashfs|nsfs",mountpoint!~"/var/lib/kubelet/pods/.+"}} / node_filesystem_files{{job="node-exporter",node=~"{n}",fstype!~"tmpfs|overlay|squashfs|nsfs",mountpoint!~"/var/lib/kubelet/pods/.+"}}', legend="{{node}} {{mountpoint}}")], unit="percentunit", min_value=0, max_value=1),
        panel("Disk Throughput", "timeseries", 0, 28, 12, 7, [target(f'rate(node_disk_read_bytes_total{{job="node-exporter",node=~"{n}",device=~"(sd|vd|xvd|nvme|mmcblk).+"}}[$__rate_interval])', "A", "{{node}} {{device}} read"), target(f'rate(node_disk_written_bytes_total{{job="node-exporter",node=~"{n}",device=~"(sd|vd|xvd|nvme|mmcblk).+"}}[$__rate_interval])', "B", "{{node}} {{device}} write")], unit="Bps"),
        panel("Disk Operation Latency", "timeseries", 12, 28, 12, 7, [target(f'rate(node_disk_read_time_seconds_total{{job="node-exporter",node=~"{n}",device=~"(sd|vd|xvd|nvme|mmcblk).+"}}[$__rate_interval]) / clamp_min(rate(node_disk_reads_completed_total{{job="node-exporter",node=~"{n}",device=~"(sd|vd|xvd|nvme|mmcblk).+"}}[$__rate_interval]), 0.001)', "A", "{{node}} {{device}} read"), target(f'rate(node_disk_write_time_seconds_total{{job="node-exporter",node=~"{n}",device=~"(sd|vd|xvd|nvme|mmcblk).+"}}[$__rate_interval]) / clamp_min(rate(node_disk_writes_completed_total{{job="node-exporter",node=~"{n}",device=~"(sd|vd|xvd|nvme|mmcblk).+"}}[$__rate_interval]), 0.001)', "B", "{{node}} {{device}} write")], unit="s", description="Average device service time per completed operation."),
        panel("PVC Backing Filesystem Used (may be shared)", "bargauge", 0, 35, 12, 7, [target('max by(node,namespace,persistentvolumeclaim) (kubelet_volume_stats_used_bytes{job="kubelet",namespace!="",node=~"$node"} / kubelet_volume_stats_capacity_bytes{job="kubelet",namespace!="",node=~"$node"})', legend="{{node}} / {{namespace}} / {{persistentvolumeclaim}}", instant=True)], unit="percentunit", min_value=0, max_value=1, threshold=thresholds(0.8, 0.9), description="Kubelet filesystem statistics, NOT per-directory/PVC consumption. Local-path claims can share a filesystem and legitimately show identical percentages. Requested GiB is not an enforced filesystem quota. Unsupported plugins are absent."),
        panel("Mounted PVC Requested Capacity (not usage or quota)", "bargauge", 12, 35, 12, 7, [target('max by(namespace,persistentvolumeclaim) (kube_persistentvolumeclaim_resource_requests_storage_bytes{job="kube-state-metrics"}) and on(namespace,persistentvolumeclaim) (max by(namespace,persistentvolumeclaim) (kube_pod_spec_volumes_persistentvolumeclaims_info{job="kube-state-metrics"} * on(namespace,pod) group_left(node) max by(namespace,pod,node) (kube_pod_info{job="kube-state-metrics",node=~"$node"})))', legend="{{namespace}} / {{persistentvolumeclaim}}", instant=True)], unit="bytes", min_value=0, description="Requested size for claims referenced by pods on selected nodes. This is neither measured consumption nor a local-path quota. Unmounted claims are excluded."),
        row("Network", 42),
        panel("Network Throughput", "timeseries", 0, 43, 12, 7, [target(f'sum by(node) (rate(node_network_receive_bytes_total{{job="node-exporter",node=~"{n}",device!~"lo|veth.*|cni.*|flannel.*"}}[$__rate_interval]))', "A", "{{node}} receive"), target(f'sum by(node) (rate(node_network_transmit_bytes_total{{job="node-exporter",node=~"{n}",device!~"lo|veth.*|cni.*|flannel.*"}}[$__rate_interval]))', "B", "{{node}} transmit")], unit="Bps"),
        panel("Network Drops and Errors", "timeseries", 12, 43, 12, 7, [target(f'sum by(node) (rate(node_network_receive_drop_total{{job="node-exporter",node=~"{n}",device!~"lo|veth.*"}}[$__rate_interval]) + rate(node_network_receive_errs_total{{job="node-exporter",node=~"{n}",device!~"lo|veth.*"}}[$__rate_interval]))', "A", "{{node}} receive"), target(f'sum by(node) (rate(node_network_transmit_drop_total{{job="node-exporter",node=~"{n}",device!~"lo|veth.*"}}[$__rate_interval]) + rate(node_network_transmit_errs_total{{job="node-exporter",node=~"{n}",device!~"lo|veth.*"}}[$__rate_interval]))', "B", "{{node}} transmit")], unit="pps"),
    ]
    p.extend([
        row("Spike investigation — drag across a graph to zoom every panel", 50),
        panel("CPU by Kubernetes Container", "timeseries", 0, 51, 12, 8,
              [target('sum by(node,namespace,pod,container) (rate(container_cpu_usage_seconds_total{job="kubelet-cadvisor",node=~"$node",container!="",container!="POD",pod!=""}[$__rate_interval]))', legend="{{node}} / {{namespace}} / {{pod}} / {{container}}")], unit="cores", links=POD_LINK,
              description="Historical container CPU on selected nodes. Drag over a host CPU spike above to inspect the same interval here. Includes terminated pods while their samples are retained; host processes outside containers are not attributed."),
        panel("CPU by Docker Container", "timeseries", 12, 51, 12, 8,
              [target('sum by(host,name) (rate(container_cpu_usage_seconds_total{job="cadvisor",host=~"$node",name!="",image!=""}[$__rate_interval]))', legend="{{host}} / {{name}}")], unit="cores",
              description="Docker cAdvisor CPU in cores. Host processes outside Docker are not collected; empty means no matching Docker telemetry, not zero host CPU."),
        panel("CPU by Mode", "timeseries", 0, 59, 12, 7,
              [target('avg by(node,mode) (rate(node_cpu_seconds_total{job="node-exporter",node=~"$node",mode!="idle"}[$__rate_interval]))', legend="{{node}} / {{mode}}")], unit="percentunit", min_value=0,
              description="Distinguishes userspace/system CPU from iowait and hypervisor steal. Process-level profiling is not currently collected."),
        panel("Memory by Kubernetes Container", "timeseries", 12, 59, 12, 7,
              [target('max by(node,namespace,pod,container) (container_memory_working_set_bytes{job="kubelet-cadvisor",node=~"$node",container!="",container!="POD",pod!=""})', legend="{{node}} / {{namespace}} / {{pod}} / {{container}}")], unit="bytes", links=POD_LINK),
        panel("Fan Speed", "timeseries", 0, 66, 12, 7,
              [target('node_hwmon_fan_rpm{job="node-exporter",node=~"$node"}', legend="{{node}} / {{chip}} / {{sensor}}")], unit="rotrpm", min_value=0,
              description="Hardware fan RPM exposed by Linux hwmon. No data means the host/driver exposes no fan sensor; it does not mean the fan is stopped."),
        panel("Hardware Temperature", "timeseries", 12, 66, 12, 7,
              [target('node_hwmon_temp_celsius{job="node-exporter",node=~"$node"}', legend="{{node}} / {{chip}} / {{sensor}}")], unit="celsius"),
    ])
    # Normalize older external-host samples at query time, without rewriting history.
    def normalize_host(match: re.Match) -> str:
        rate_metric, rate_labels, interval, gauge_metric, gauge_labels = match.groups()
        metric, labels = (rate_metric, rate_labels) if rate_metric else (gauge_metric, gauge_labels)
        external = labels.replace('node=~"$node"', 'node="",host=~"$node"')
        local_expr = f'{metric}{{{labels},node!=""}}'
        external_expr = f'{metric}{{{external}}}'
        if rate_metric:
            local_expr = f'rate({local_expr}[{interval}])'
            external_expr = f'rate({external_expr}[{interval}])'
        return f'({local_expr} or label_replace({external_expr}, "node", "$1", "host", "(.+)"))'

    for item in p:
        for query in item.get("targets", []):
            if item["type"] == "stat" and not query.get("legendFormat"):
                query["legendFormat"] = item["title"]
            # Rates need a range selector on the raw metric, so normalize after rate.
            query["expr"] = re.sub(
                r'rate\((node_\w+)\{([^{}]*node=~"\$node"[^{}]*)\}\[([^]]+)\]\)'
                r'|\b(node_\w+)\{([^{}]*node=~"\$node"[^{}]*)\}',
                normalize_host, query["expr"])
    variables = [prom_var("node", 'query_result(count by(node) (node_uname_info{job="node-exporter",node!=""} or label_replace(node_uname_info{job="node-exporter",node="",host!=""}, "node", "$1", "host", "(.+)")))', multi=True, include_all=True)]
    variables[0]["regex"] = '/node="([^"]+)"/'
    p[1]["title"] = "Kubernetes Readiness"
    p[1]["description"] = "Readiness of selected Kubernetes nodes. External Docker hosts have no Kubernetes readiness and show no data when selected alone."
    return dashboard("Nodes / Hosts", "obs-nodes", p, variables, tags=["infrastructure"])


def workloads_dashboard() -> dict:
    selector = 'namespace=~"$namespace",workload=~"$workload",workload_type=~"$workload_type"'
    owner = f'namespace_workload_pod:kube_pod_owner:relabel{{{selector}}}'
    p = [
        row("Deployment health", 0),
        panel("Unavailable Deployment Replicas", "stat", 0, 1, 4, 4, [target('sum(clamp_min(kube_deployment_spec_replicas{job="kube-state-metrics",namespace=~"$namespace"} - kube_deployment_status_replicas_available{job="kube-state-metrics",namespace=~"$namespace"}, 0))', instant=True)], threshold=thresholds(1, 3)),
        panel("Unavailable StatefulSet Replicas", "stat", 4, 1, 4, 4, [target('sum(clamp_min(kube_statefulset_replicas{job="kube-state-metrics",namespace=~"$namespace"} - kube_statefulset_status_replicas_ready{job="kube-state-metrics",namespace=~"$namespace"}, 0))', instant=True)], threshold=thresholds(1, 2)),
        panel("Unavailable DaemonSet Pods", "stat", 8, 1, 4, 4, [target('sum(kube_daemonset_status_number_unavailable{job="kube-state-metrics",namespace=~"$namespace"})', instant=True)], threshold=thresholds(1, 2)),
        panel("Pending Pods", "stat", 12, 1, 4, 4, [target('sum(kube_pod_status_phase{job="kube-state-metrics",namespace=~"$namespace",phase="Pending"} == 1) or vector(0)', instant=True)], threshold=thresholds(1, 4)),
        panel("Unschedulable Pods", "stat", 16, 1, 4, 4, [target('sum(kube_pod_status_unschedulable{job="kube-state-metrics",namespace=~"$namespace"} == 1) or vector(0)', instant=True)], threshold=thresholds(1, 2)),
        panel("Restarts (1h)", "stat", 20, 1, 4, 4, [target('sum(increase(kube_pod_container_status_restarts_total{job="kube-state-metrics",namespace=~"$namespace"}[1h]))', instant=True)], threshold=thresholds(1, 5), decimals=1),
        panel("Unavailable Replicas by Workload (empty is healthy)", "timeseries", 0, 5, 12, 7, [target('clamp_min(kube_deployment_spec_replicas{job="kube-state-metrics",namespace=~"$namespace"} - kube_deployment_status_replicas_available{job="kube-state-metrics",namespace=~"$namespace"}, 0) > 0', "A", "{{namespace}} deployment/{{deployment}}"), target('clamp_min(kube_statefulset_replicas{job="kube-state-metrics",namespace=~"$namespace"} - kube_statefulset_status_replicas_ready{job="kube-state-metrics",namespace=~"$namespace"}, 0) > 0', "B", "{{namespace}} statefulset/{{statefulset}}"), target('kube_daemonset_status_number_unavailable{job="kube-state-metrics",namespace=~"$namespace"} > 0', "C", "{{namespace}} daemonset/{{daemonset}}")], min_value=0),
        panel("Pods by Phase", "timeseries", 12, 5, 12, 7, [target('sum by(namespace,phase) (kube_pod_status_phase{job="kube-state-metrics",namespace=~"$namespace"} == 1)', legend="{{namespace}} {{phase}}")], min_value=0),
        row("Workload resource use", 12),
        panel("Workload CPU Usage", "timeseries", 0, 13, 12, 7, [target(f'namespace_workload:container_cpu_usage_seconds_total:sum_rate5m{{{selector}}}', legend="{{namespace}} / {{workload}} ({{workload_type}})")], unit="cores"),
        panel("Workload Memory Working Set", "timeseries", 12, 13, 12, 7, [target(f'namespace_workload:container_memory_working_set_bytes:sum{{{selector}}}', legend="{{namespace}} / {{workload}} ({{workload_type}})")], unit="bytes"),
        panel("CPU Usage vs Requests", "timeseries", 0, 20, 12, 7, [target(f'namespace_workload:container_cpu_usage_seconds_total:sum_rate5m{{{selector}}}', "A", "{{workload}} usage"), target(f'sum by(namespace,workload,workload_type) (max by(namespace,pod,container) (kube_pod_container_resource_requests{{job="kube-state-metrics",resource="cpu",namespace=~"$namespace"}}) * on(namespace,pod) group_left(workload,workload_type) {owner})', "B", "{{workload}} requests")], unit="cores", description="Usage and requested CPU are plotted separately; they are not percentages."),
        panel("Memory Usage vs Requests", "timeseries", 12, 20, 12, 7, [target(f'namespace_workload:container_memory_working_set_bytes:sum{{{selector}}}', "A", "{{workload}} usage"), target(f'sum by(namespace,workload,workload_type) (max by(namespace,pod,container) (kube_pod_container_resource_requests{{job="kube-state-metrics",resource="memory",namespace=~"$namespace"}}) * on(namespace,pod) group_left(workload,workload_type) {owner})', "B", "{{workload}} requests")], unit="bytes"),
        row("Instability and consumers", 27),
        panel("Pods Restarting", "bargauge", 0, 28, 8, 7, [target('topk(15, sum by(namespace,pod) (increase(kube_pod_container_status_restarts_total{job="kube-state-metrics",namespace=~"$namespace"}[1h])) > 0)', legend="{{namespace}} / {{pod}}", instant=True)], links=POD_LINK, threshold=thresholds(1, 3), decimals=1),
        panel("Last Termination Was OOMKilled", "table", 8, 28, 8, 7, [target('kube_pod_container_status_last_terminated_reason{job="kube-state-metrics",namespace=~"$namespace",reason="OOMKilled"} == 1', instant=True, fmt="table")], links=POD_LINK, description="Current containers whose most recent recorded termination reason is OOMKilled."),
        panel("Containers Not Ready (empty is healthy)", "table", 16, 28, 8, 7, [target('(kube_pod_container_status_ready{job="kube-state-metrics",namespace=~"$namespace"} == 0) * on(namespace,pod) group_left() (max by(namespace,pod) (kube_pod_status_phase{job="kube-state-metrics",namespace=~"$namespace",phase=~"Pending|Running"}) == 1)', instant=True, fmt="table")], links=POD_LINK, description="Containers whose Kubernetes Ready condition is currently false."),
        panel("Top CPU Workloads", "bargauge", 0, 35, 12, 7, [target(f'topk(15, namespace_workload:container_cpu_usage_seconds_total:sum_rate5m{{{selector}}})', legend="{{namespace}} / {{workload}}", instant=True)], unit="cores"),
        panel("Top Memory Workloads", "bargauge", 12, 35, 12, 7, [target(f'topk(15, namespace_workload:container_memory_working_set_bytes:sum{{{selector}}})', legend="{{namespace}} / {{workload}}", instant=True)], unit="bytes"),
    ]
    variables = [
        prom_var("namespace", 'label_values(kube_namespace_status_phase{job="kube-state-metrics"}, namespace)', multi=True, include_all=True),
        prom_var("workload_type", 'label_values(namespace_workload_pod:kube_pod_owner:relabel{namespace=~"$namespace"}, workload_type)', label="Workload type", multi=True, include_all=True),
        prom_var("workload", 'label_values(namespace_workload_pod:kube_pod_owner:relabel{namespace=~"$namespace",workload_type=~"$workload_type"}, workload)', multi=True, include_all=True),
    ]
    return dashboard("Kubernetes Workloads", "obs-workloads", p, variables, tags=["kubernetes"])


def pod_dashboard() -> dict:
    ns, podv, cont = '$namespace', '$pod', '$container'
    plink = "/d/obs-logs?var-namespace=$namespace&var-pod=$pod&var-container=$container&from=${__from}&to=${__to}"
    p = [
        row("Identity and current state", 0),
        panel("Ready or Completed", "stat", 0, 1, 4, 4, [target(f'min(max by(namespace,pod) (kube_pod_status_ready{{job="kube-state-metrics",namespace=~"{ns}",pod=~"{podv}",condition="true"}} or kube_pod_status_phase{{job="kube-state-metrics",namespace=~"{ns}",pod=~"{podv}",phase="Succeeded"}}))', instant=True)], min_value=0, max_value=1, threshold=thresholds(1, None, base="red", reverse=True), description="1 means every selected pod is Ready or has completed successfully. Completed Jobs are not treated as unhealthy."),
        panel("Restarts in Range", "stat", 4, 1, 4, 4, [target(f'sum(increase(kube_pod_container_status_restarts_total{{job="kube-state-metrics",namespace=~"{ns}",pod=~"{podv}",container=~"{cont}"}}[$__range]))', instant=True)], threshold=thresholds(1, 3), decimals=1),
        panel("Pod Age", "stat", 8, 1, 4, 4, [target(f'min(time() - kube_pod_created{{job="kube-state-metrics",namespace=~"{ns}",pod=~"{podv}"}})', instant=True)], unit="s"),
        panel("Node Placement", "table", 12, 1, 6, 4, [target(f'max by(namespace,pod,node,host_ip,pod_ip) (kube_pod_info{{job="kube-state-metrics",namespace=~"{ns}",pod=~"{podv}"}})', instant=True, fmt="table")]),
        panel("Current Waiting / Last Termination", "table", 18, 1, 6, 4, [target(f'kube_pod_container_status_waiting_reason{{job="kube-state-metrics",namespace=~"{ns}",pod=~"{podv}",container=~"{cont}"}} == 1', "A", instant=True, fmt="table"), target(f'kube_pod_container_status_last_terminated_reason{{job="kube-state-metrics",namespace=~"{ns}",pod=~"{podv}",container=~"{cont}"}} == 1', "B", instant=True, fmt="table")], description="Current waiting reason and most recent termination reason. Empty is normal for healthy running containers."),
        row("Resources", 5),
        panel("CPU Usage / Requests / Limits", "timeseries", 0, 6, 12, 8, [target(f'sum by(container) (rate(container_cpu_usage_seconds_total{{job="kubelet-cadvisor",namespace=~"{ns}",pod=~"{podv}",container=~"{cont}",container!="",container!="POD"}}[$__rate_interval]))', "A", "{{container}} usage"), target(f'sum by(container) (kube_pod_container_resource_requests{{job="kube-state-metrics",namespace=~"{ns}",pod=~"{podv}",container=~"{cont}",resource="cpu"}})', "B", "{{container}} request"), target(f'sum by(container) (kube_pod_container_resource_limits{{job="kube-state-metrics",namespace=~"{ns}",pod=~"{podv}",container=~"{cont}",resource="cpu"}})', "C", "{{container}} limit")], unit="cores"),
        panel("Memory Working Set / Requests / Limits", "timeseries", 12, 6, 12, 8, [target(f'max by(container) (container_memory_working_set_bytes{{job="kubelet-cadvisor",namespace=~"{ns}",pod=~"{podv}",container=~"{cont}",container!="",container!="POD"}})', "A", "{{container}} working set"), target(f'sum by(container) (kube_pod_container_resource_requests{{job="kube-state-metrics",namespace=~"{ns}",pod=~"{podv}",container=~"{cont}",resource="memory"}})', "B", "{{container}} request"), target(f'sum by(container) (kube_pod_container_resource_limits{{job="kube-state-metrics",namespace=~"{ns}",pod=~"{podv}",container=~"{cont}",resource="memory"}})', "C", "{{container}} limit")], unit="bytes"),
        panel("Pod Phase", "timeseries", 0, 14, 12, 7, [target(f'kube_pod_status_phase{{job="kube-state-metrics",namespace=~"{ns}",pod=~"{podv}"}} == 1', legend="{{pod}} {{phase}}")], min_value=0, max_value=1, description="The active phase is 1. Succeeded Jobs remain visibly completed instead of appearing as failed containers."),
        panel("Pod Network RX / TX", "timeseries", 12, 14, 12, 7, [target(f'sum by(pod) (rate(container_network_receive_bytes_total{{job="kubelet-cadvisor",namespace=~"{ns}",pod=~"{podv}"}}[$__rate_interval]))', "A", "{{pod}} receive"), target(f'sum by(pod) (rate(container_network_transmit_bytes_total{{job="kubelet-cadvisor",namespace=~"{ns}",pod=~"{podv}"}}[$__rate_interval]))', "B", "{{pod}} transmit")], unit="Bps"),
        row("Restarts and evidence", 21),
        panel("Container Restart Counter", "timeseries", 0, 22, 12, 7, [target(f'kube_pod_container_status_restarts_total{{job="kube-state-metrics",namespace=~"{ns}",pod=~"{podv}",container=~"{cont}"}}', legend="{{container}}")], min_value=0),
        panel("Kubernetes Events for Pod (empty is healthy)", "logs", 12, 22, 12, 7, [log_target(f'{{job="kubernetes-events",namespace="{ns}"}} | logfmt | name=~"{podv}"')], datasource=LOKI),
        panel("Recent Pod Logs", "logs", 0, 29, 24, 10, [log_target(f'{{namespace="{ns}",pod=~"{podv}",container=~"{cont}"}} |~ "$search"')], datasource=LOKI, links=[{"title": "Open Logs dashboard", "url": plink, "targetBlank": False}], description="Raw workload logs with the same namespace, pod, container and time range."),
    ]
    variables = [
        prom_var("namespace", 'label_values(kube_namespace_status_phase{job="kube-state-metrics"}, namespace)', current="monitoring"),
        prom_var("workload", 'label_values(namespace_workload_pod:kube_pod_owner:relabel{namespace="$namespace"}, workload)', current="prometheus"),
        prom_var("pod", 'label_values(namespace_workload_pod:kube_pod_owner:relabel{namespace="$namespace",workload="$workload"}, pod)', multi=True, include_all=True),
        prom_var("container", 'label_values(kube_pod_container_info{job="kube-state-metrics",namespace="$namespace",pod=~"$pod"}, container)', multi=True, include_all=True),
        text_var("search", ".*", "Log regex"),
    ]
    return dashboard("Pod / Container Drilldown", "obs-pod", p, variables, tags=["kubernetes"], time_from="now-1h")


def logs_dashboard() -> dict:
    selector = '{namespace=~"$namespace",app=~"$app",pod=~"$pod",container=~"$container"}'
    p = [
        row("Volume and concentration", 0),
        panel("Log Lines / Second by Namespace", "timeseries", 0, 1, 12, 7, [log_target('sum by(namespace) (rate({namespace=~"$namespace"}[$__auto]))', legend="{{namespace}}")], datasource=LOKI, unit="ops"),
        panel("Log Lines / Second by Application", "timeseries", 12, 1, 12, 7, [log_target(f'sum by(app) (rate({selector}[$__auto]))', legend="{{app}}")], datasource=LOKI, unit="ops", description="The app label comes only from app.kubernetes.io/name or app pod labels; unlabeled workloads appear with an empty app value."),
        panel("Noisiest Pods", "bargauge", 0, 8, 12, 7, [log_target(f'topk(15, sum by(namespace,pod) (rate({selector}[$__auto])))', legend="{{namespace}} / {{pod}}")], datasource=LOKI, unit="ops", links=POD_LINK),
        panel("Explicit Error / Warning Tokens", "timeseries", 12, 8, 12, 7, [log_target(f'sum by(namespace) (rate({selector} |~ "(?i)\\\\b(error|warn(ing)?|fatal|panic)\\\\b" [$__auto]))', legend="{{namespace}}")], datasource=LOKI, unit="ops", description="Content match only; this does not assign a severity to unstructured logs."),
        row("Investigation", 15),
        panel("Filtered Workload Logs", "logs", 0, 16, 24, 11, [log_target(f'{selector} |~ "$search"')], datasource=LOKI, description="Use a RE2 regex in Log regex. Start broad, then narrow namespace → app → pod → container."),
        panel("Kubernetes Warning Events", "logs", 0, 27, 24, 8, [log_target('{job="kubernetes-events",namespace=~"$namespace"} | logfmt | type="Warning" |~ "$event_search"')], datasource=LOKI, description="Events are API objects rendered as logfmt. Empty is healthy."),
    ]
    variables = [
        loki_var("namespace", 'label_values({namespace=~".+"}, namespace)', multi=True, include_all=True),
        loki_var("app", 'label_values({namespace=~"$namespace"}, app)', multi=True, include_all=True),
        loki_var("pod", 'label_values({namespace=~"$namespace",app=~"$app"}, pod)', multi=True, include_all=True),
        loki_var("container", 'label_values({namespace=~"$namespace",pod=~"$pod"}, container)', multi=True, include_all=True),
        text_var("search", ".*", "Log regex"),
        text_var("event_search", ".*", "Event regex"),
    ]
    return dashboard("Kubernetes Logs", "obs-logs", p, variables, tags=["logs"], time_from="now-1h")


def traefik_dashboard() -> dict:
    ep = 'kubernetes_service="traefik-metrics",entrypoint=~"$entrypoint"'
    router = 'kubernetes_service="traefik-metrics",router=~"$router"'
    service = 'kubernetes_service="traefik-metrics",service=~"$service"'
    p = [
        row("Request health", 0),
        panel("Request Rate", "stat", 0, 1, 6, 4, [target(f'sum(rate(traefik_entrypoint_requests_total{{{ep}}}[5m]))', instant=True)], unit="reqps"),
        panel("HTTP 5xx Ratio", "stat", 6, 1, 6, 4, [target(f'(sum(rate(traefik_entrypoint_requests_total{{{ep},code=~"5.."}}[5m])) / clamp_min(sum(rate(traefik_entrypoint_requests_total{{{ep}}}[5m])), 0.001)) or vector(0)', instant=True)], unit="percentunit", min_value=0, max_value=1, threshold=thresholds(0.01, 0.05), description="Server-error request ratio; zero is healthy."),
        panel("HTTP 4xx Ratio", "stat", 12, 1, 6, 4, [target(f'sum(rate(traefik_entrypoint_requests_total{{{ep},code=~"4.."}}[5m])) / clamp_min(sum(rate(traefik_entrypoint_requests_total{{{ep}}}[5m])), 0.001)', instant=True)], unit="percentunit", min_value=0, max_value=1, threshold=thresholds(0.1, 0.25), description="Client errors can be expected; investigate changes rather than treating every 4xx as an incident."),
        panel("Services Returning 5xx", "stat", 18, 1, 6, 4, [target('count(sum by(service) (rate(traefik_service_requests_total{kubernetes_service="traefik-metrics",code=~"5.."}[5m])) > 0) or vector(0)', instant=True)], threshold=thresholds(1, 2), description="Number of Traefik services currently returning server errors; zero is healthy."),
        panel("Requests by Status Class", "timeseries", 0, 5, 12, 7, [target(f'sum by(code) (rate(traefik_entrypoint_requests_total{{{ep}}}[$__rate_interval]))', legend="HTTP {{code}}")], unit="reqps"),
        panel("Request Latency", "timeseries", 12, 5, 12, 7, [target(f'histogram_quantile(0.50, sum by(le,entrypoint) (rate(traefik_entrypoint_request_duration_seconds_bucket{{{ep}}}[$__rate_interval])))', "A", "{{entrypoint}} p50"), target(f'histogram_quantile(0.95, sum by(le,entrypoint) (rate(traefik_entrypoint_request_duration_seconds_bucket{{{ep}}}[$__rate_interval])))', "B", "{{entrypoint}} p95"), target(f'histogram_quantile(0.99, sum by(le,entrypoint) (rate(traefik_entrypoint_request_duration_seconds_bucket{{{ep}}}[$__rate_interval])))', "C", "{{entrypoint}} p99")], unit="s"),
        row("Routing and backends", 12),
        panel("Request Rate by Router", "timeseries", 0, 13, 12, 7, [target(f'sum by(router) (rate(traefik_router_requests_total{{{router}}}[$__rate_interval]))', legend="{{router}}")], unit="reqps"),
        panel("5xx Rate by Router", "timeseries", 12, 13, 12, 7, [target(f'sum by(router) (rate(traefik_router_requests_total{{{router},code=~"5.."}}[$__rate_interval])) or vector(0)', legend="{{router}}")], unit="reqps", description="Server-error request rate by router; an unlabeled zero means no router emitted a 5xx in the selected interval."),
        panel("Request Rate by Service", "timeseries", 0, 20, 12, 7, [target(f'sum by(service) (rate(traefik_service_requests_total{{{service}}}[$__rate_interval]))', legend="{{service}}")], unit="reqps"),
        panel("Service p95 Latency", "timeseries", 12, 20, 12, 7, [target(f'histogram_quantile(0.95, sum by(le,service) (rate(traefik_service_request_duration_seconds_bucket{{{service}}}[$__rate_interval])))', legend="{{service}}")], unit="s", description="End-to-end request latency grouped by the Traefik backend service."),
        panel("Traffic Bytes", "timeseries", 0, 27, 12, 7, [target(f'sum by(entrypoint) (rate(traefik_entrypoint_requests_bytes_total{{{ep}}}[$__rate_interval]))', "A", "{{entrypoint}} request"), target(f'sum by(entrypoint) (rate(traefik_entrypoint_responses_bytes_total{{{ep}}}[$__rate_interval]))', "B", "{{entrypoint}} response")], unit="Bps"),
        panel("Open Connections", "timeseries", 12, 27, 12, 7, [target(f'sum by(entrypoint,protocol) (traefik_open_connections{{{ep}}})', legend="{{entrypoint}} {{protocol}}")], unit="short"),
        row("Reachability from Fuji", 34),
        panel("Public Probe Success", "timeseries", 0, 35, 12, 7, [target('probe_success{job="blackbox-http"}', legend="{{instance}}")], min_value=0, max_value=1, threshold=thresholds(1, None, base="red", reverse=True)),
        panel("DNS / Connect / TLS / Processing", "timeseries", 12, 35, 12, 7, [target('probe_http_duration_seconds{job="blackbox-http"}', legend="{{instance}} {{phase}}")], unit="s", description="Phase breakdown for the internal blackbox probe. It does not represent an external user's network path."),
    ]
    variables = [
        prom_var("entrypoint", 'label_values(traefik_entrypoint_requests_total{kubernetes_service="traefik-metrics"}, entrypoint)', multi=True, include_all=True),
        prom_var("router", 'label_values(traefik_router_requests_total{kubernetes_service="traefik-metrics"}, router)', multi=True, include_all=True),
        prom_var("service", 'label_values(traefik_service_requests_total{kubernetes_service="traefik-metrics"}, service)', multi=True, include_all=True),
        text_var("status", "4..|5..", "Evidence status regex"),
        text_var("request_host", ".*", "Request host regex"),
        text_var("request_path", ".*", "Request path regex"),
    ]
    access = ('{namespace="kube-system",container="traefik"} | json '
              '| __error__="" | DownstreamStatus=~"$status" '
              '| entryPointName=~"$entrypoint" | RouterName=~"$router" '
              '| ServiceName=~"$service" | RequestHost=~"$request_host" '
              '| RequestPath=~"$request_path"')
    for item in p:
        if item["title"] == "5xx Rate by Router":
            item["title"] = "4xx / 5xx by Router and Status"
            item["targets"] = [target(f'sum by(router,service,code) (rate(traefik_router_requests_total{{{router},service=~"$service",code=~"4..|5.."}}[$__rate_interval]))', legend="{{router}} → {{service}} / HTTP {{code}}")]
            item["description"] = "Identify the route and backend for each error status. Router metrics do not include entrypoint labels; use request evidence below for entrypoint filtering and unmatched-route errors."
        if item["title"] == "Requests by Status Class":
            item["title"] = "Entrypoint Requests by HTTP Status"
        if item["type"] == "stat":
            item["description"] += " Evaluated at the selected range end. Entrypoint summaries are independent of router/service evidence filters."
            for query in item["targets"]:
                query["legendFormat"] = item["title"]
        if item["title"] == "Services Returning 5xx":
            item["targets"][0]["expr"] = f'count(sum by(service) (rate(traefik_service_requests_total{{{service},code=~"5.."}}[$__rate_interval])) > 0) or (0 * count(up{{kubernetes_service="traefik-metrics"}} == 1))'
            item["description"] = "Selected backend services returning 5xx at the range end. Independent of entrypoint/router filters. No data if no healthy scrape target."
        for query in item.get("targets", []):
            query["expr"] = query["expr"].replace("[5m]", "[$__rate_interval]")
            # Preserve a healthy zero only when the selected request series exists.
            if item["title"] in ("HTTP 4xx Ratio", "HTTP 5xx Ratio"):
                code = "4.." if "4xx" in item["title"] else "5.."
                total = f'sum(rate(traefik_entrypoint_requests_total{{{ep}}}[$__rate_interval]))'
                query["expr"] = f'(sum(rate(traefik_entrypoint_requests_total{{{ep},code=~"{code}"}}[$__rate_interval])) or (0 * {total})) / clamp_min({total}, 0.001)'
    p.extend([
        row("Error investigation — zoom a spike, then narrow router / service / status", 42),
        panel("Backend Errors by Service and Status", "timeseries", 0, 43, 12, 7,
              [target(f'sum by(service,code) (rate(traefik_service_requests_total{{{service},code=~"4..|5.."}}[$__rate_interval]))', legend="{{service}} / HTTP {{code}}")], unit="reqps",
              description="Service-level errors across all entrypoints. No matching series can mean no errors or missing telemetry; check scrape health."),
        panel("Error Responses in Selected Range", "bargauge", 12, 43, 12, 7,
              [target(f'sum by(router,service,code) (increase(traefik_router_requests_total{{{router},service=~"$service",code=~"$status"}}[$__range])) > 0', legend="{{router}} / {{service}} / {{code}}", instant=True)], min_value=0,
              description="Estimated counter increase over the highlighted time range. Includes every matching route, without hiding small error counts behind a top-k cutoff."),
        panel("Failed / Slow Requests — Host, Path, Route, Backend", "logs", 0, 50, 24, 10,
              [log_target(access)], datasource=LOKI,
              description="JSON access evidence: RequestHost, RequestPath, RouterName, ServiceName, DownstreamStatus (client response), OriginStatus (backend response), Duration and OriginDuration in nanoseconds. Expand a line for fields. Collected after access logging is deployed: all 4xx/5xx OR requests taking at least 1s. Use status .* to include slow successes. Missing route/backend identifies failures before routing; select All to retain them. No historical backfill."),
        panel("Traefik Internal Errors", "logs", 0, 60, 12, 8,
              [log_target('{namespace="kube-system",container="traefik"} |~ "(?i)(error|warn|fatal)"')], datasource=LOKI,
              description="Controller/configuration/TLS errors in the same time window. Global Traefik logs; request filters do not apply."),
        panel("Traefik Metrics Scrape Health", "timeseries", 12, 60, 12, 8,
              [target('up{kubernetes_service="traefik-metrics"}', legend="{{instance}}")], min_value=0, max_value=1,
              description="0 means scrape failed; absent means no retained target samples. This is not HTTP request success."),
    ])
    return dashboard("Edge / Traefik", "obs-traefik", p, variables, tags=["traffic"])


def stack_dashboard() -> dict:
    p = [
        row("Component health", 0),
        panel("Prometheus", "stat", 0, 1, 4, 4, [target('min(up{job="prometheus"})', instant=True)], min_value=0, max_value=1, threshold=thresholds(1, None, base="red", reverse=True)),
        panel("Grafana", "stat", 4, 1, 4, 4, [target('min(up{job="grafana"})', instant=True)], min_value=0, max_value=1, threshold=thresholds(1, None, base="red", reverse=True)),
        panel("Loki", "stat", 8, 1, 4, 4, [target('min(up{job="kubernetes-services",kubernetes_service="loki"})', instant=True)], min_value=0, max_value=1, threshold=thresholds(1, None, base="red", reverse=True)),
        panel("Alloy Node Coverage", "stat", 12, 1, 6, 4, [target('sum(up{job="kubernetes-services",kubernetes_service="alloy"} == 1) / count(kube_node_info{job="kube-state-metrics"})', instant=True)],
              unit="percentunit", min_value=0, max_value=1,
              threshold=thresholds(0.999, 0.9, base="red", reverse=True),
              description="Share of Kubernetes nodes with a healthy Alloy pod-log collector."),
        panel("Node Exporter Coverage", "stat", 18, 1, 6, 4, [target('sum(up{job="node-exporter"} == 1) / count(kube_node_info{job="kube-state-metrics"})', instant=True)],
              unit="percentunit", min_value=0, max_value=1,
              threshold=thresholds(0.999, 0.9, base="red", reverse=True),
              description="Share of Kubernetes nodes with a healthy node-exporter target."),
        panel("Scrape Targets Down", "table", 0, 5, 12, 7, [target('up == 0', instant=True, fmt="table")], description="Empty is healthy."),
        panel("Scrape Duration", "timeseries", 12, 5, 12, 7, [target('max by(job) (scrape_duration_seconds)', legend="{{job}}")], unit="s"),
        row("Prometheus", 12),
        panel("Samples Ingested", "timeseries", 0, 13, 8, 7, [target('rate(prometheus_tsdb_head_samples_appended_total{job="prometheus"}[$__rate_interval])', legend="samples")], unit="ops"),
        panel("Head Series", "timeseries", 8, 13, 8, 7, [target('prometheus_tsdb_head_series{job="prometheus"}', legend="series")]),
        panel("TSDB Block Bytes", "timeseries", 16, 13, 8, 7, [target('prometheus_tsdb_storage_blocks_bytes{job="prometheus"}', legend="blocks")], unit="bytes"),
        panel("Rule Evaluation Failures", "timeseries", 0, 20, 24, 7, [target('sum by(rule_group) (rate(prometheus_rule_evaluation_failures_total{job="prometheus"}[$__rate_interval]))', legend="{{rule_group}}")], unit="ops"),
        row("Logs pipeline", 27),
        panel("Loki Lines Ingested", "timeseries", 0, 28, 8, 7, [target('sum(rate(loki_distributor_lines_received_total{kubernetes_service="loki"}[$__rate_interval]))', legend="lines")], unit="ops"),
        panel("Loki Discarded Samples", "timeseries", 8, 28, 8, 7, [target('sum by(reason) (rate(loki_discarded_samples_total{kubernetes_service="loki"}[$__rate_interval])) or vector(0)', legend="{{reason}}")], unit="ops", description="Entries rejected by Loki limits or validation. Zero is expected."),
        panel("Loki 5xx Requests", "timeseries", 16, 28, 8, 7, [target('sum by(route) (rate(loki_request_duration_seconds_count{kubernetes_service="loki",status_code=~"5.."}[$__rate_interval])) or vector(0)', legend="{{route}}")], unit="reqps"),
        panel("Alloy Entries Sent", "timeseries", 0, 35, 8, 7, [target('sum by(instance) (rate(loki_write_sent_entries_total{kubernetes_service=~"alloy|alloy-events"}[$__rate_interval]))', legend="{{instance}}")], unit="ops"),
        panel("Alloy Send Retries", "timeseries", 8, 35, 8, 7, [target('sum by(instance) (rate(loki_write_batch_retries_total{kubernetes_service=~"alloy|alloy-events"}[$__rate_interval])) or vector(0)', legend="{{instance}}")], unit="ops"),
        panel("Alloy Dropped Entries", "timeseries", 16, 35, 8, 7, [target('sum by(instance,reason) (rate(loki_write_dropped_entries_total{kubernetes_service=~"alloy|alloy-events"}[$__rate_interval])) or vector(0)', legend="{{instance}} {{reason}}")], unit="ops"),
        row("API and UI", 42),
        panel("Kubernetes API Requests", "timeseries", 0, 43, 24, 7, [target('sum by(code) (rate(apiserver_request_total{job="kubernetes-apiserver"}[$__rate_interval]))', legend="HTTP {{code}}")], unit="reqps"),
    ]
    return dashboard("Observability Stack", "obs-stack", p, [], tags=["monitoring"])


def render_configmap(name: str, key: str, body: dict) -> str:
    rendered = json.dumps(body, indent=2, sort_keys=False) + "\n"
    indented = "".join("    " + line if line.strip() else line for line in rendered.splitlines(keepends=True))
    return (
        "apiVersion: v1\n"
        "kind: ConfigMap\n"
        "metadata:\n"
        f"  name: {name}\n"
        "  namespace: monitoring\n"
        "  annotations:\n"
        "    argocd.argoproj.io/sync-options: ServerSideApply=true\n"
        "data:\n"
        f"  {key}: |\n{indented}"
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true", help="fail if committed dashboard ConfigMaps are stale")
    args = parser.parse_args()
    dashboards = [
        ("grafana-dashboard-platform-overview-configmap.yaml", "grafana-dashboard-platform-overview", "platform-overview.json", platform_overview()),
        ("grafana-dashboard-nodes-configmap.yaml", "grafana-dashboard-nodes", "nodes.json", nodes_dashboard()),
        ("grafana-dashboard-kubernetes-workloads-configmap.yaml", "grafana-dashboard-kubernetes-workloads", "kubernetes-workloads.json", workloads_dashboard()),
        ("grafana-dashboard-pod-drilldown-configmap.yaml", "grafana-dashboard-pod-drilldown", "pod-drilldown.json", pod_dashboard()),
        ("grafana-dashboard-kubernetes-logs-configmap.yaml", "grafana-dashboard-kubernetes-logs", "kubernetes-logs.json", logs_dashboard()),
        ("grafana-dashboard-traefik-configmap.yaml", "grafana-dashboard-traefik", "traefik.json", traefik_dashboard()),
        ("grafana-dashboard-observability-stack-configmap.yaml", "grafana-dashboard-observability-stack", "observability-stack.json", stack_dashboard()),
    ]
    stale: list[str] = []
    for filename, name, key, body in dashboards:
        path = ROOT / filename
        content = render_configmap(name, key, body)
        if args.check:
            if not path.exists() or path.read_text() != content:
                stale.append(filename)
        else:
            path.write_text(content)
    if stale:
        print("Generated dashboard ConfigMaps are stale: " + ", ".join(stale), file=sys.stderr)
        print("Run generate-dashboards.py and commit the results.", file=sys.stderr)
        return 1
    if args.check:
        print("Generated dashboard ConfigMaps are current")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
