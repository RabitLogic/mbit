#!/usr/bin/env bash
#
# mbit benchmark suite.
#
# Builds the shadow app, starts it, runs a multi-endpoint baseline at
# concurrency=100 and a concurrency sweep on /json, sampling the server RSS
# around each run. Prints one JSON line per loadgen run (QPS / latency
# percentiles / error rate).
#
# Usage:
#   ./bench/bench.sh [mode] [port] [duration]
#     mode     : obs | plain   (default obs)
#     port     : default 18081
#     duration : seconds per run (default 8)
set -u
cd "$(dirname "$0")/.."
MODE="${1:-obs}"
PORT="${2:-18081}"
DUR="${3:-8}"
LOGGEN="python3 bench/loadgen.py"
BIN=_build/native/debug/build/bench/bench.exe
BASE="http://127.0.0.1:$PORT"

echo "## building (mode=$MODE, port=$PORT, dur=${DUR}s)"
moon build --target native --warn-list "-0035-0029" >/dev/null 2>&1 || { echo "BUILD FAILED"; exit 1; }

MBIT_BENCH_MODE="$MODE" "$BIN" >/tmp/mbit_bench_server.log 2>&1 &
SRV=$!
trap 'kill $SRV 2>/dev/null; wait $SRV 2>/dev/null' EXIT

for _ in $(seq 1 50); do
  if curl -s -o /dev/null "$BASE/"; then break; fi
  sleep 0.2
done
echo "## server pid=$SRV ready"

echo "### [1] baseline: endpoints @ concurrency=100"
for ep in "/" "/json" "/hello/bench" "/query?q=bench" "/api/users/42"; do
  $LOGGEN --url "$BASE$ep" --concurrency 100 --duration "$DUR"
done
$LOGGEN --url "$BASE/echo" --concurrency 100 --duration "$DUR" \
  --method POST --body '{"a":1}' --content-type application/json

echo "### [2] concurrency sweep on /json (100 -> 5000)"
for c in 100 500 1000 2000 3000 5000; do
  rss1=$(ps -o rss= -p "$SRV" 2>/dev/null | tr -d ' ')
  $LOGGEN --url "$BASE/json" --concurrency "$c" --duration "$DUR"
  rss2=$(ps -o rss= -p "$SRV" 2>/dev/null | tr -d ' ')
  echo "{\"phase\":\"sweep\",\"concurrency\":$c,\"rss_before_kb\":$rss1,\"rss_after_kb\":$rss2}"
done
