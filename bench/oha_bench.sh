#!/usr/bin/env bash
#
# mbit benchmark suite driven by `oha` — a real, C-warped Rust HTTP load
# generator (hyper-based, epoll, keep-alive, latency percentiles), replacing
# the pure-Python loader which was the bottleneck in earlier numbers.
#
# Usage:
#   ./bench/oha_bench.sh [mode] [port] [duration]
#     mode     : obs | plain   (default obs)
#     port     : default 18081
#     duration : seconds per run (default 8)
set -u
cd "$(dirname "$0")/.."
MODE="${1:-obs}"
PORT="${2:-18081}"
DUR="${3:-8}"
OHA="${OHA:-$HOME/.local/bin/oha}"
BIN=_build/native/debug/build/bench/bench.exe
BASE="http://127.0.0.1:$PORT"

[ -x "$OHA" ] || { echo "ERROR: oha not found at $OHA (install: cargo install oha)"; exit 1; }

echo "## building (mode=$MODE, port=$PORT, dur=${DUR}s)"
moon build --target native --warn-list "-0035-0029" >/dev/null 2>&1 || { echo "BUILD FAILED"; exit 1; }

MBIT_BENCH_MODE="$MODE" "$BIN" >/tmp/mbit_bench_server.log 2>&1 &
SRV=$!
trap 'kill $SRV 2>/dev/null; wait $SRV 2>/dev/null' EXIT
for _ in $(seq 1 50); do
  if curl -s -o /dev/null "$BASE/"; then break; fi
  sleep 0.2
done
echo "## server pid=$SRV ready (mode=$MODE)"

# Run one oha load and emit a compact JSON line.
# All remaining args are passed to oha (URL last).
run() {
  local label="$1"; shift
  local out qps p50 p99 codes
  out=$("$OHA" --no-tui --http-version 1.1 -t 10s "$@" 2>&1)
  qps=$(echo "$out" | awk '/Requests\/sec:/{print $2; exit}')
  p50=$(echo "$out" | awk '/50.00% in/{print $3; exit}')
  p99=$(echo "$out" | awk '/99.00% in/{print $3; exit}')
  codes=$(echo "$out" | awk '
    /Status code distribution:/{f=1; next}
    f && /^  \[/{ code=$1; n=$2; gsub(/[\[\]]/,"",code); printf "%s:%s ", code, n }
    f && /Error distribution:/{f=0}')
  echo "{\"ep\":\"$label\",\"qps\":\"$qps\",\"p50\":\"$p50\",\"p99\":\"$p99\",\"codes\":\"$codes\"}"
}

echo "### [1] baseline: endpoints @ concurrency=100"
run "/"        -c 100 -z "${DUR}s" "$BASE/"
run "/json"    -c 100 -z "${DUR}s" "$BASE/json"
run "/hello/:name" -c 100 -z "${DUR}s" "$BASE/hello/bench"
run "/query"   -c 100 -z "${DUR}s" "$BASE/query?q=bench"
run "/api/users/:id" -c 100 -z "${DUR}s" "$BASE/api/users/42"
run "POST /echo" -c 100 -z "${DUR}s" -m POST -T application/json -d '{"a":1}' "$BASE/echo"

echo "### [2] POST /upload (multipart, 1 KiB file)"
printf -- '--MBITBOUND123\r\nContent-Disposition: form-data; name="file"; filename="t.bin"\r\nContent-Type: application/octet-stream\r\n\r\n' > /tmp/mbit_mp_head.bin
head -c 1024 /dev/urandom > /tmp/mbit_mp_data.bin
printf -- '\r\n--MBITBOUND123--\r\n' > /tmp/mbit_mp_tail.bin
cat /tmp/mbit_mp_head.bin /tmp/mbit_mp_data.bin /tmp/mbit_mp_tail.bin > /tmp/mbit_upload_body.bin
run "POST /upload(1KiB)" -c 100 -z "${DUR}s" -m POST \
  -T 'multipart/form-data; boundary=MBITBOUND123' -D /tmp/mbit_upload_body.bin "$BASE/upload"

echo "### [3] concurrency sweep on /json (100 -> 5000)"
for c in 100 500 1000 2000 3000 5000; do
  rss1=$(ps -o rss= -p "$SRV" 2>/dev/null | tr -d ' ')
  run "sweep c=$c" -c "$c" -z "${DUR}s" "$BASE/json"
  rss2=$(ps -o rss= -p "$SRV" 2>/dev/null | tr -d ' ')
  echo "{\"phase\":\"sweep\",\"concurrency\":$c,\"rss_before_kb\":\"$rss1\",\"rss_after_kb\":\"$rss2\"}"
done

echo "### [4] /slow queueing behavior"
run "/slow c=1"   -c 1 -n 5 "$BASE/slow"
run "/slow c=50"  -c 50 -z "${DUR}s" "$BASE/slow"

echo "### [5] /api/limited rate limit (20 req / 10s)"
run "/api/limited c=20" -c 20 -z 3s "$BASE/api/limited"

rm -f /tmp/mbit_mp_head.bin /tmp/mbit_mp_data.bin /tmp/mbit_mp_tail.bin /tmp/mbit_upload_body.bin
echo "## done"
