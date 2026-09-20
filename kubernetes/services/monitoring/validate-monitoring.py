#!/usr/bin/env python3
"""Static validation for monitoring manifests and generated dashboards."""

from __future__ import annotations

import json
import argparse
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

import yaml


ROOT = Path(__file__).resolve().parent
MAX_CONFIGMAP_BYTES = 1_000_000
ALLOWED_DATASOURCES = {"prometheus", "loki", "-- Mixed --", "-- Grafana --"}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--promql-rules-output", type=Path)
    parser.add_argument("--prometheus-files-output", type=Path)
    parser.add_argument("--logql-output", type=Path)
    parser.add_argument("--logql-url")
    parser.add_argument("--loki-config-output", type=Path)
    parser.add_argument("--core-only", action="store_true")
    parser.add_argument("--alloy-files-output", type=Path)
    parser.add_argument("--prometheus-url")
    args = parser.parse_args()
    errors: list[str] = []
    configmaps: set[str] = set()
    configmap_keys: dict[str, set[str]] = {}
    dashboards: dict[str, Path] = {}
    parsed: dict[Path, list[dict]] = {}
    promql_expressions: list[tuple[str, str]] = []
    logql_expressions: list[tuple[str, str]] = []

    for path in sorted(ROOT.glob("*.yaml")):
        try:
            documents = [d for d in yaml.safe_load_all(path.read_text()) if isinstance(d, dict)]
        except Exception as exc:
            errors.append(f"{path.name}: invalid YAML: {exc}")
            continue
        parsed[path] = documents
        for document in documents:
            if document.get("kind") == "ConfigMap":
                name = document.get("metadata", {}).get("name")
                if name:
                    configmaps.add(name)
                    configmap_keys[name] = set((document.get("data") or {}).keys())
                encoded = len(path.read_bytes())
                if encoded >= MAX_CONFIGMAP_BYTES:
                    errors.append(f"{path.name}: {encoded} bytes is too close to the Kubernetes object limit")

            if not path.name.startswith("grafana-dashboard-"):
                continue
            for key, value in (document.get("data") or {}).items():
                try:
                    model = json.loads(value)
                except Exception as exc:
                    errors.append(f"{path.name}:{key}: invalid dashboard JSON: {exc}")
                    continue
                uid = model.get("uid")
                if not uid:
                    errors.append(f"{path.name}:{key}: missing dashboard UID")
                elif uid in dashboards:
                    errors.append(f"dashboard UID {uid!r} is duplicated in {dashboards[uid].name} and {path.name}")
                else:
                    dashboards[uid] = path
                for panel in model.get("panels", []):
                    grid = panel.get("gridPos", {})
                    if grid.get("x", 0) + grid.get("w", 0) > 24:
                        errors.append(f"{path.name}:{panel.get('title')}: panel exceeds 24-column grid")
                    datasource = panel.get("datasource")
                    if isinstance(datasource, dict):
                        ds_uid = datasource.get("uid")
                        if ds_uid and ds_uid not in ALLOWED_DATASOURCES:
                            errors.append(f"{path.name}:{panel.get('title')}: unknown datasource UID {ds_uid}")
                    if panel.get("type") != "row" and not panel.get("targets"):
                        errors.append(f"{path.name}:{panel.get('title')}: panel has no query target")
                    for query in panel.get("targets", []):
                        ds = query.get("datasource")
                        if isinstance(ds, dict) and ds.get("uid") not in ALLOWED_DATASOURCES:
                            errors.append(f"{path.name}:{panel.get('title')}: unknown target datasource {ds.get('uid')}")
                        if not (query.get("expr") or query.get("query")):
                            errors.append(f"{path.name}:{panel.get('title')}: empty query")
                        include_query = not args.core_only or "observability-core" in model.get("tags", [])
                        if include_query and isinstance(ds, dict) and ds.get("uid") == "prometheus" and query.get("expr"):
                            promql_expressions.append((f"{model.get('uid')} / {panel.get('title')}", query["expr"]))
                        if include_query and isinstance(ds, dict) and ds.get("uid") == "loki" and query.get("expr"):
                            logql_expressions.append((f"{model.get('uid')} / {panel.get('title')}", query["expr"]))

    workloads = parsed.get(ROOT / "workloads.yaml", [])
    projected: set[str] = set()
    projected_paths: set[str] = set()
    grafana_home_path: str | None = None
    for document in workloads:
        if document.get("kind") != "Deployment" or document.get("metadata", {}).get("name") != "grafana":
            continue
        for volume in document["spec"]["template"]["spec"].get("volumes", []):
            if volume.get("name") != "dashboards":
                continue
            for source in volume.get("projected", {}).get("sources", []):
                configmap = source.get("configMap", {})
                name = configmap.get("name")
                if name:
                    projected.add(name)
                    for item in configmap.get("items", []):
                        key, item_path = item.get("key"), item.get("path")
                        if key not in configmap_keys.get(name, set()):
                            errors.append(f"Grafana projection {name} references missing key {key!r}")
                        if not item_path:
                            errors.append(f"Grafana projection {name}/{key} has no path")
                        elif item_path in projected_paths:
                            errors.append(f"Grafana dashboard path is duplicated: {item_path}")
                        else:
                            projected_paths.add(item_path)
        for container in document["spec"]["template"]["spec"].get("containers", []):
            if container.get("name") != "grafana":
                continue
            for env in container.get("env", []):
                if env.get("name") == "GF_DASHBOARDS_DEFAULT_HOME_DASHBOARD_PATH":
                    grafana_home_path = env.get("value")
    missing = sorted(projected - configmaps)
    if missing:
        errors.append(f"Grafana projects missing ConfigMaps: {', '.join(missing)}")
    dashboard_root = "/var/lib/grafana/dashboards/"
    if not grafana_home_path or not grafana_home_path.startswith(dashboard_root):
        errors.append("Grafana home dashboard path is missing or outside the dashboard volume")
    elif grafana_home_path.removeprefix(dashboard_root) not in projected_paths:
        errors.append(f"Grafana home dashboard is not projected: {grafana_home_path}")

    if args.promql_rules_output:
        substitutions = {
            "$__rate_interval": "5m",
            "$__range_s": "3600",
            "$__interval_ms": "300000",
            "$__range": "1h",
            "$__interval": "5m",
            "$bucket_size": "5m",
        }
        rules = []
        for index, (source, expression) in enumerate(promql_expressions):
            for old, new in substitutions.items():
                expression = expression.replace(old, new)
            expression = re.sub(
                r"\$(node|namespace|workload|workload_type|pod|container|entrypoint|router|service)",
                ".*",
                expression,
            )
            expression = re.sub(r"\$[A-Za-z_][A-Za-z0-9_]*", ".*", expression)
            rules.append({"record": f"dashboard_query_validation_{index}", "expr": expression,
                          "labels": {"source": source[:120]}})
        args.promql_rules_output.parent.mkdir(parents=True, exist_ok=True)
        args.promql_rules_output.write_text(yaml.safe_dump({"groups": [{"name": "dashboard-query-validation", "rules": rules}]}, sort_keys=False))

    if args.prometheus_url:
        substitutions = {
            "$__rate_interval": "5m",
            "$__range_s": "3600",
            "$__interval_ms": "300000",
            "$__range": "1h",
            "$__interval": "5m",
            "$bucket_size": "5m",
        }
        for source, expression in promql_expressions:
            for old, new in substitutions.items():
                expression = expression.replace(old, new)
            expression = re.sub(r"\$[A-Za-z_][A-Za-z0-9_]*", ".*", expression)
            params = urllib.parse.urlencode({"query": expression})
            url = f"{args.prometheus_url.rstrip('/')}/api/v1/query?{params}"
            try:
                with urllib.request.urlopen(url, timeout=10) as response:
                    payload = json.load(response)
                if payload.get("status") != "success":
                    errors.append(f"{source}: Prometheus rejected query: {payload}")
                    continue
                result = payload.get("data", {}).get("result", [])
                print(f"PROMQL series={len(result):3d} {source}")
            except urllib.error.HTTPError as exc:
                errors.append(f"{source}: Prometheus query failed: {exc}; {exc.read().decode(errors='replace')[:500]}")
            except (urllib.error.URLError, TimeoutError, json.JSONDecodeError) as exc:
                errors.append(f"{source}: Prometheus query failed: {exc}")

    if args.prometheus_files_output:
        args.prometheus_files_output.mkdir(parents=True, exist_ok=True)
        prometheus_documents = parsed.get(ROOT / "prometheus-configmap.yaml", [])
        if prometheus_documents:
            for key, value in prometheus_documents[0].get("data", {}).items():
                (args.prometheus_files_output / key).write_text(value)

    if args.logql_output:
        output = []
        for source, expression in logql_expressions:
            for variable, value in {
                "$__rate_interval": "5m",
                "$__interval": "5m",
                "$__range": "1h",
                "$__auto": "5m",
                "$bucket_size": "5m",
            }.items():
                expression = expression.replace(variable, value)
            expression = expression.replace("$namespace", ".+").replace("$host", ".+")
            expression = re.sub(
                r"\$(namespace|app|pod|container|search|event_search)",
                ".*",
                expression,
            )
            expression = re.sub(r"\$[A-Za-z_][A-Za-z0-9_]*", ".*", expression)
            output.append({"source": source, "expr": expression})
        args.logql_output.parent.mkdir(parents=True, exist_ok=True)
        args.logql_output.write_text(json.dumps(output, indent=2) + "\n")

    if args.loki_config_output:
        loki_documents = parsed.get(ROOT / "loki-alloy-configmap.yaml", [])
        loki_config = next(
            (document.get("data", {}).get("config.yml") for document in loki_documents
             if document.get("kind") == "ConfigMap" and document.get("metadata", {}).get("name") == "loki-config"),
            None,
        )
        if loki_config is None:
            errors.append("loki-config ConfigMap or config.yml key not found")
        else:
            args.loki_config_output.parent.mkdir(parents=True, exist_ok=True)
            args.loki_config_output.write_text(loki_config)

    if args.alloy_files_output:
        args.alloy_files_output.mkdir(parents=True, exist_ok=True)
        alloy_documents = parsed.get(ROOT / "loki-alloy-configmap.yaml", [])
        for document in alloy_documents:
            name = document.get("metadata", {}).get("name")
            if name not in {"alloy-config", "alloy-events-config"}:
                continue
            config = document.get("data", {}).get("config.alloy")
            if config is None:
                errors.append(f"{name} has no config.alloy key")
            else:
                (args.alloy_files_output / f"{name}.alloy").write_text(config)

    if args.logql_url:
        end = int(time.time() * 1_000_000_000)
        start = end - 3_600_000_000_000
        for source, expression in logql_expressions:
            for variable, value in {
                "$__rate_interval": "5m",
                "$__interval": "5m",
                "$__range": "1h",
                "$__auto": "5m",
                "$bucket_size": "5m",
            }.items():
                expression = expression.replace(variable, value)
            # Use a real chained dashboard selection so exact matchers are tested
            # as well as regex matchers. These values are part of the core stack.
            live_values = {
                "$namespace": "monitoring",
                "$app": "prometheus",
                "$pod": "prometheus-0",
                "$container": "prometheus",
                "$search": ".*",
                "$event_search": ".*",
                "$host": ".+",
            }
            for variable, value in live_values.items():
                expression = expression.replace(variable, value)
            expression = re.sub(r"\$[A-Za-z_][A-Za-z0-9_]*", ".*", expression)
            params = urllib.parse.urlencode({"query": expression, "start": start, "end": end, "limit": 10})
            url = f"{args.logql_url.rstrip('/')}/loki/api/v1/query_range?{params}"
            try:
                with urllib.request.urlopen(url, timeout=10) as response:
                    payload = json.load(response)
                if payload.get("status") != "success":
                    errors.append(f"{source}: Loki rejected query: {payload}")
                else:
                    result = payload.get("data", {}).get("result", [])
                    print(f"LOGQL  series={len(result):3d} {source}")
            except urllib.error.HTTPError as exc:
                errors.append(f"{source}: Loki query failed: {exc}; {exc.read().decode(errors='replace')[:500]}")
            except (urllib.error.URLError, TimeoutError, json.JSONDecodeError) as exc:
                errors.append(f"{source}: Loki query failed: {exc}")

    print(f"YAML files: {len(parsed)}")
    print(f"ConfigMaps: {len(configmaps)}")
    print(f"Dashboards: {len(dashboards)} ({', '.join(sorted(dashboards))})")
    print(f"Projected dashboard ConfigMaps: {len(projected)}")
    print(f"Prometheus dashboard expressions: {len(promql_expressions)}")
    print(f"Loki dashboard expressions: {len(logql_expressions)}")
    if errors:
        print("\nValidation errors:", file=sys.stderr)
        print("\n".join(f"- {error}" for error in errors), file=sys.stderr)
        return 1
    print("Static monitoring validation passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
