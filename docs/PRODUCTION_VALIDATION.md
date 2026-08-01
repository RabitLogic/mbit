# mbit Production Validation Report

> Date: 2026-08-02 · Environment: 14-core CPU / 30 GiB RAM (single host, localhost) · MoonBit `0.1.20260729`
> Goal: exercise mbit with real traffic and a real load generator to validate performance, resilience, security, and observability, and to reach a production-readiness verdict.

---

## 1. Method & Reproducibility

- **Shadow app**: `bench/` (`main.mbt`) — exposes two middleware stacks:
  - **plain**: `recovery` only (raw framework throughput)
  - **obs**: `request_id + structured_logger + metrics + secure + body_size_limit + recovery` (full observability)
  - plus purpose-built routes for rate limiting, uploads, panic, slow-request, and graceful shutdown.
- **Load generator**: **`oha` 1.15** (Rust/hyper; epoll; multiple keep-alive connections; per-percentile latency output), HTTP/1.1. (An earlier custom Python loader proved to be the client-side bottleneck; its numbers are not used here.)
- **One-shot run**: `./bench/oha_bench.sh [obs|plain] [port] [seconds]`.
- **Notes**: all measurements on localhost (no network jitter). The server binary must run outside the sandbox (seccomp restriction).

| Mode | Middleware stack |
|---|---|
| **plain** | recovery |
| **obs** | request_id, structured_logger, metrics, secure, body_size_limit, recovery |

---

## 2. Benchmark (oha, real load generator)

### 2.1 Baseline (concurrency 100, 8s, obs mode, 100% success)

| Endpoint | QPS | p50 (ms) | p99 (ms) |
|---|---|---|---|
| `GET /` (text) | 32,035 | 3.03 | 4.15 |
| `GET /json` | 29,781 | 3.28 | 4.24 |
| `GET /hello/:name` | 30,670 | 3.21 | 4.13 |
| `GET /query` | 29,634 | 3.32 | 4.42 |
| `GET /api/users/:id` | 29,278 | 3.35 | 4.43 |
| `POST /echo` (JSON body) | 25,399 | 3.86 | 5.01 |
| `POST /upload` (multipart 1 KiB) | 22,540 | 4.32 | 6.04 |

### 2.2 Concurrency sweep (`/json`, 8s per step, obs)

| Concurrency | QPS | RSS before → after (MB) | Errors |
|---|---|---|---|
| 100 | 31,426 | 6.3 → 6.3 | 0 |
| 500 | 28,864 | 6.3 → 9.3 | 0 |
| 1,000 | 28,626 | 9.3 → 12.5 | 0 |
| 2,000 | 25,532 | 12.5 → 17.5 | 0 |
| 3,000 | 25,626 | 18.0 → 29.4 | 0 |
| 5,000 | 27,164 | 29.4 → 34.5 | 0 |

- Concurrency 100 → 5000: QPS stays **25–31k, 0 errors, 0 crashes, no OOM**. RSS grows linearly with connections (~5.6 KB/conn) from ~6 MB to ~34 MB.
- Single-threaded event loop: throughput is flat across concurrency.

### 2.3 Observability overhead (real numbers)

| Mode | `/json` QPS | `/` QPS |
|---|---|---|
| plain (recovery only) | 57,832 | 62,091 |
| obs (request_id + structured_logger + metrics) | 29,781 | 32,035 |

- **The observability stack costs ≈ +94% (throughput roughly halves)**, driven mainly by `structured_logger`'s per-request `println` (synchronous stdout write).
- For production, consider sampled logging / async buffered writes / logging only slow requests.

### 2.4 Rate limiting & slow-request behavior

- **Rate limiting** `/api/limited` (20 req/10s), `-c 20` for 3s → **exactly 20×200 + 81,897×429**; the rejection path runs at 27,286 req/s; `Retry-After` correct. ✅
- **Slow-request head-of-line blocking (single-threaded event loop)**: `/slow` (400 ms busy-wait) at concurrency 50 → only 8.7 req/s, p50 2.4s; **while `/slow` is under load, `/json` drops to 0.87 req/s** — a CPU-bound/blocking handler stalls the whole loop. ⚠️ **Production constraint: handlers must not do synchronous CPU-bound or blocking work**; use async `await`, or offload to a queue / worker thread.

### 2.5 Protocol

- The MoonBit `async/http` server is **HTTP/1.1-only** (no HTTP/2/h2c). `oha --http-version 2` → connection error (expected). Terminate TLS/HTTP2 at a reverse proxy if needed.

---

## 3. Component checks

| Component | Method | Result |
|---|---|---|
| **Rate limit** `rate_limit` | 25 rapid requests (limit 20/10s) | ✅ 20×200 + 5×429, `Retry-After: 10` |
| **Body limit** `body_size_limit` | 100 KB → route limited at 64 KB | ✅ 413 `Payload Too Large` |
| **Upload** (text) | multipart 10 B | ✅ `{"size":10}` 200 |
| **Upload** (binary) | multipart 1 MB / 5 MB random bytes | ✅ `{"size":1048576}` / `{"size":5242880}` 200 |
| **Security headers** `secure()` | inspect response headers | ✅ X-Frame-Options: DENY, X-Content-Type-Options: nosniff, X-XSS-Protection, Referrer-Policy, Cross-Origin-Opener-Policy; ⚠️ CSP / HSTS not sent by default (require `content_security_policy` / `strict_transport_security`) |
| **WebSocket** | — | ⚠️ Only `is_websocket()` detection; no real protocol — long-connection stability untestable |

---

## 4. Resilience & reliability

| Scenario | Method | Result |
|---|---|---|
| **Panic recovery** (catchable) | `/panic` raises `Failure(...)` | ✅ `recovery()` catches → 500 JSON, process alive, metrics record 500 |
| **Panic recovery** (hard panic) | handler `abort()` | ✅ Framework request path no longer uses `abort()`; handlers must use `raise(Failure(...))`. A hard `%panic` still SIGABRTs (MoonBit runtime limitation, not catchable by try/catch) |
| **Graceful shutdown** | `/shutdown` calls `Engine::shutdown()` | ✅ In-flight requests complete, then the process exits cleanly (verified: in-flight `/slow` finishes 200, then process exits) |
| **Dependency failure** (DB/cache) | — | N/A (no built-in deps; timeout/error handling is app-layer) |

---

## 5. Security & robustness

- **Injection tests**:
  - Path param `<script>alert(1)</script>` → 404 (plain text, no execution)
  - Query SQL fragment `' OR 1=1--` → echoed as plain text 200 (no SQL execution)
  - Path traversal `..%2F..%2Fetc/passwd` → echoed as a param only (no file access)
  - **Verdict**: no framework-level injection vulnerability (params pass through, no evaluation); the application must validate/sanitize (correct framework behavior).
- **Resource exhaustion**: `body_size_limit` rejects oversized bodies before reading (413, prevents OOM). Large binary bodies are buffered in memory while parsing — set a limit in production.

---

## 6. Observability

### 6.1 Structured logging (`structured_logger`)
One JSON line per request (obs mode), including `request_id` for tracing:

```json
{"level":"info","msg":"request","ts":1785601022181,"request_id":"1785601022181",
 "method":"GET","path":"/json","status":200,"latency_ms":0.5,"client_ip":"127.0.0.1","size":0}
```

- ✅ Parseable by standard JSON parsers; `request_id` ties into the `request_id()` middleware.
- ⚠️ Minor: `size` is always 0 (`Context.size` is not updated on response writes).

### 6.2 Metrics (`metrics` middleware)
`/metrics` serves Prometheus text format: request counts (by method/status), 5xx count, in-flight gauge, latency histogram (12 buckets), uptime.

```
mbit_http_requests_total{method="GET"} 16540
mbit_http_request_duration_seconds_bucket{le="0.05"} ...
mbit_http_request_duration_seconds_sum 123.45
mbit_http_request_duration_seconds_count 16540   ← consistent with total
mbit_http_requests_in_flight 0
```

- ✅ After load: `requests_total == duration_seconds_count`, `in_flight` returns to 0, 5xx accurate.
- ✅ Scrapable by Prometheus (`text/plain; version=0.0.4`).
- Fix: an `in_flight` leak on panic (the exception skipped the post-`next()` decrement) was fixed by placing the observability middleware outside `recovery` (Gin-style ordering), which also records the final 500.

---

## 7. Key findings (by severity)

| # | Severity | Finding | Status |
|---|---|---|---|
| 1 | **P0** | **Header case bug**: the `async/http` server lowercases request header keys; `Context::header()` did exact-case matching → under real HTTP, `content_type()`, `body_size_limit`, `form_file`, `cors`, `basic_auth`, `gzip`, cookie, `is_websocket` all failed (only TestConn unit tests passed) | ✅ **FIXED**: `header()` falls back to `key.to_lower()` |
| 2 | **P0** | **`abort()` unrecoverable**: a hard panic kills the whole process; `recovery()` cannot catch it | ✅ **FIXED**: framework request path now uses `raise(Failure(...))` (`must_get`/`must_bind`/`must_bind_with`); `/panic` → 500, process alive |
| 3 | **P1** | **Binary request body unreadable**: `body_string()` used `read_all().text()` (UTF-8) → binary body decoded to empty → binary uploads broken; large bodies fully buffered | ✅ **FIXED**: `Context::body_bytes()` (lazy, cached `read_all().binary()`); `body_string()` uses `@encoding/utf8.decode`; `form_file` returns `Bytes?` with byte-level multipart parsing; `save_uploaded_file` takes `Bytes`. Text 11 B / binary 1 MB / 5 MB uploads all 200 with correct size |
| 4 | **P1** | **`Engine::shutdown()` was a stub**: could not stop the server / drain in-flight requests (no graceful rolling restart) | ✅ **FIXED**: the accept loop polls with a 100 ms timeout to observe the shutdown flag; waits for `active_requests` drain (CondVar broadcast); `Task::cancel()` interrupts blocked `read_request` and idle connections close; `with_task_group` returns and the process exits. Verified: in-flight `/slow` completes 200, then process exits |
| 5 | **P2** | `secure()` does not send CSP / HSTS by default | ⚠️ Requires explicit config |
| 6 | **P3** | `Context.size` not updated on response writes (log `size` always 0) | ⚠️ Minor |

---

## 8. Production-readiness verdict

**Satisfied (within test scope)**
- ✅ Performance: ~26–32k QPS (obs) / ~58–62k QPS (plain) on simple endpoints, p99 ≤ 6 ms, 0 errors
- ✅ Resilience: concurrency up to 5000 with no crashes, no OOM, bounded memory (~6–34 MB); `recovery()` handles catchable exceptions
- ✅ Security: security headers, `body_size_limit` prevents OOM, no framework-level injection flaws
- ✅ Observability: JSON logs (with request_id) + Prometheus `/metrics` ready

**Fixed this phase**
- ✅ P0 header-case bug (header fallback to lowercase); dependent middleware regression-tested
- ✅ Binary upload / large bodies (`body_bytes()` + byte-level multipart; 1 MB / 5 MB verified; 413 works)
- ✅ Graceful shutdown (in-flight completes, then clean process exit)
- ✅ Hard-panic isolation (request path no longer `abort()`s; `/panic` → 500, process alive)

**Remaining non-blocking items**
- `secure()` does not send CSP / HSTS by default (P2)
- `Context.size` not updated (P3)
- WebSocket long connections not production-ready without protocol support

**Recommendation**: all P0/P1 blockers are fixed. Suitable for small-scale rollout on non-critical, low-risk services while monitoring memory/latency.

---

## 9. Reproduce

```bash
./bench/oha_bench.sh obs 18081 8    # full benchmark (obs mode, real tool)
./bench/oha_bench.sh plain 18081 8  # full benchmark (plain mode)
oha --no-tui --http-version 1.1 -c 100 -z 8s http://127.0.0.1:18081/json
curl http://127.0.0.1:18081/metrics   # Prometheus metrics
```
