#!/usr/bin/env python3
"""
mbit load generator — measures QPS, latency percentiles and error rate.

Wrk-style: every worker keeps firing for a fixed wall-clock window; QPS and
latency percentiles are computed over requests that COMPLETED inside the window
(no drain-time distortion), even under heavy queueing.

Usage:
  python3 loadgen.py --url http://127.0.0.1:18081/json --concurrency 200 --duration 10
                     [--method POST --body '{"k":1}' --content-type application/json]

Outputs one JSON line to stdout:
  {"url":..., "concurrency":..., "duration":..., "requests":..., "qps":...,
   "avg_ms":..., "p50_ms":..., "p90_ms":..., "p99_ms":..., "p999_ms":...,
   "max_ms":..., "errors":..., "error_rate":..., "status_codes":{...}}
"""
import argparse
import http.client
import json
import statistics
import threading
import time
import urllib.parse

LOCK = threading.Lock()
RESULTS = []  # (latency_ms, status, end_time)


def _parse_url(url):
    u = urllib.parse.urlsplit(url)
    host = u.hostname
    port = u.port or (443 if u.scheme == "https" else 80)
    path = u.path or "/"
    if u.query:
        path = path + "?" + u.query
    return host, port, path


def worker(host, port, method, path, body, headers, deadline, results):
    conn = http.client.HTTPConnection(host, port, timeout=60)
    while time.time() < deadline:
        start = time.perf_counter()
        try:
            conn.request(method, path, body=body, headers=headers)
            resp = conn.getresponse()
            resp.read()
            status = resp.status
        except Exception:
            status = 0
            try:
                conn.close()
            except Exception:
                pass
            conn = http.client.HTTPConnection(host, port, timeout=60)
        lat = (time.perf_counter() - start) * 1000.0
        results.append((lat, status, time.time()))
    try:
        conn.close()
    except Exception:
        pass


def percentile(sorted_lat, p):
    if not sorted_lat:
        return 0.0
    idx = min(len(sorted_lat) - 1, int(p / 100.0 * (len(sorted_lat) - 1)))
    return sorted_lat[idx]


def main():
    ap = argparse.ArgumentParser(description="mbit load generator")
    ap.add_argument("--url", default="http://127.0.0.1:18081/json")
    ap.add_argument("--concurrency", type=int, default=100)
    ap.add_argument("--duration", type=float, default=10.0)
    ap.add_argument("--method", default="GET")
    ap.add_argument("--body", default=None)
    ap.add_argument("--content-type", default=None)
    args = ap.parse_args()

    host, port, path = _parse_url(args.url)
    deadline = time.time() + args.duration
    headers = {}
    if args.content_type:
        headers["Content-Type"] = args.content_type
    body = args.body.encode() if args.body else None
    if body is not None:
        headers["Content-Length"] = str(len(body))

    threads = []
    for _ in range(args.concurrency):
        t = threading.Thread(
            target=worker,
            args=(host, port, args.method, path, body, headers, deadline, RESULTS),
            daemon=True,
        )
        t.start()
        threads.append(t)

    # wait for the window, then give threads a moment to record
    time.sleep(args.duration + 1.0)
    for t in threads:
        t.join(timeout=3)

    in_window = [r for r in RESULTS if r[2] <= deadline]
    total = len(in_window)
    lat = [r[0] for r in in_window]
    statuses = [r[1] for r in in_window]
    qps = total / args.duration if args.duration > 0 else 0.0
    err = sum(1 for s in statuses if s == 0 or s >= 500)
    status_map = {}
    for s in statuses:
        status_map[s] = status_map.get(s, 0) + 1
    lat_sorted = sorted(lat)
    out = {
        "url": args.url,
        "concurrency": args.concurrency,
        "duration": args.duration,
        "requests": total,
        "qps": round(qps, 1),
        "avg_ms": round(statistics.mean(lat), 3) if lat else 0.0,
        "p50_ms": round(percentile(lat_sorted, 50), 3),
        "p90_ms": round(percentile(lat_sorted, 90), 3),
        "p99_ms": round(percentile(lat_sorted, 99), 3),
        "p999_ms": round(percentile(lat_sorted, 99.9), 3),
        "max_ms": round(lat_sorted[-1], 3) if lat_sorted else 0.0,
        "errors": err,
        "error_rate": round(err / total, 4) if total else 0.0,
        "status_codes": status_map,
    }
    print(json.dumps(out))


if __name__ == "__main__":
    main()
