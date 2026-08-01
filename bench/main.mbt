///|
/// mbit production-validation "shadow" app.
///
/// Modes (via env `MBIT_BENCH_MODE`):
///   - "plain": minimal stack (recovery only) — raw framework throughput.
///   - "obs"  : full observability stack (request_id, structured_logger,
///              metrics, secure, body_size_limit, recovery) — the default.
///
/// Routes:
///   GET  /                 plain text
///   GET  /json             JSON object response
///   GET  /hello/:name      path parameter
///   GET  /query            query parameter
///   POST /echo             JSON body echo
///   GET  /api/users/:id    path-param JSON
///   POST /upload           multipart file upload (returns size)
///   POST /upload-small     upload capped at 64 KB (body_size_limit -> 413)
///   GET  /panic            aborts — recovered as 500
///   GET  /slow             busy-waits ~400 ms (graceful-shutdown test)
///   GET  /api/limited      rate-limited (20 req / 10 s)
///   GET  /metrics          Prometheus metrics (obs mode only)

async fn h_json(ctx : @core.Context) -> Unit {
  ctx.json(200, Json::object(@core.h([("msg", Json::string("ok")), ("n", Json::number(42.0))])))
}

async fn h_text(ctx : @core.Context) -> Unit {
  ctx.string(200, "hello")
}

async fn h_hello(ctx : @core.Context) -> Unit {
  ctx.string(200, "Hello, " + ctx.param_default("name", "?") + "!")
}

async fn h_query(ctx : @core.Context) -> Unit {
  ctx.string(200, "q=" + ctx.query_default("q", ""))
}

async fn h_echo(ctx : @core.Context) -> Unit {
  match ctx.body_json() {
    Some(j) => ctx.json(200, j)
    None => ctx.json(400, Json::object(@core.h([("error", Json::string("bad json"))])))
  }
}

async fn h_user(ctx : @core.Context) -> Unit {
  ctx.json(200, Json::object(@core.h([("id", Json::string(ctx.param_default("id", "")))])))
}

async fn h_upload(ctx : @core.Context) -> Unit {
  match ctx.form_file("file") {
    Some(c) => ctx.json(200, Json::object(@core.h([("size", Json::number(c.length().to_double()))])))
    None => ctx.json(400, Json::object(@core.h([("error", Json::string("no file"))])))
  }
}

async fn h_panic(ctx : @core.Context) -> Unit {
  // NOTE: `raise(Failure(...))` is a catchable exception that `recovery()`
  // handles (returns 500). `abort("...")` is a HARD panic that terminates the
  // whole process and CANNOT be recovered by try/catch — see report.
  raise(Failure("boom"))
}

async fn h_slow(ctx : @core.Context) -> Unit {
  let end = @env.now() + 400UL
  while @env.now() < end {
    ()
  }
  ctx.string(200, "slow done")
}

async fn h_limited(ctx : @core.Context) -> Unit {
  ctx.string(200, "limited ok")
}

async fn h_shutdown(ctx : @core.Context) -> Unit {
  let app = @core.new()
  let ok = app.shutdown(cleanup=fn() { println("[bench] cleanup called") })
  ctx.string(200, "shutdown returned " + ok.to_string())
}

async fn h_404(ctx : @core.Context) -> Unit {
  ctx.json(404, Json::object(@core.h([("error", Json::string("not found"))])))
}

async fn main {
  let mode = match @env.get_env_var("MBIT_BENCH_MODE") {
    Some(m) => m
    None => "obs"
  }
  let app = @core.new()
  // Observability middleware go OUTSIDE recovery (matching Gin): so that
  // after an inner panic is recovered to 500, metrics/loggers see the final
  // status and their post-`next()` bookkeeping still runs.
  if mode != "plain" {
    app.use(@middleware.request_id()) |> ignore
    app.use(@middleware.structured_logger()) |> ignore
    app.use(@middleware.metrics()) |> ignore
  }
  app.use(@core.recovery()) |> ignore
  if mode != "plain" {
    app.use(@middleware.secure(@middleware.SecureConfig::default())) |> ignore
    app.use(@middleware.body_size_limit(64L * 1024L * 1024L)) |> ignore
  }
  app.get("/", [h_text]) |> ignore
  app.get("/json", [h_json]) |> ignore
  app.get("/hello/:name", [h_hello]) |> ignore
  app.get("/query", [h_query]) |> ignore
  app.post("/echo", [h_echo]) |> ignore
  app.get("/api/users/:id", [h_user]) |> ignore
  app.post("/upload", [h_upload]) |> ignore
  app.post("/upload-small", [
    @middleware.body_size_limit(64L * 1024L),
    h_upload,
  ]) |> ignore
  app.get("/panic", [h_panic]) |> ignore
  app.get("/slow", [h_slow]) |> ignore
  app.get("/api/limited", [
    @middleware.rate_limit(@middleware.RateLimitConfig::{ max_requests: 20, window_secs: 10 }),
    h_limited,
  ]) |> ignore
  app.get("/shutdown", [h_shutdown]) |> ignore
  app.no_route([h_404]) |> ignore
  app.run("127.0.0.1:18081")
}
