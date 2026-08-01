///|
/// Logger middleware — logs each request with method, path, status, and latency.
///
/// See `logger.go` equivalent.
///
/// Usage:
/// ```
/// app.use(logger())
/// ```

pub fn logger() -> Handler {
  async fn(ctx) {
    let start = @env.now()
    // Run the rest of the chain
    ctx.next()
    // After the chain completes
    let elapsed = @env.now() - start
    let status = ctx.status_code
    let meth = ctx.http_method()
    let path = ctx.path()
    let client_ip = ctx.client_ip()
    println("\{client_ip} [\{meth}] \{path} -> \{status} (\{elapsed}ms)")
  }
}
