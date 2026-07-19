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
  fn(ctx) {
    let start = @async.now()
    // Run the rest of the chain
    ctx.next()
    // After the chain completes
    let elapsed = @async.now() - start
    let status = ctx.status_code
    let meth = ctx.method()
    let path = ctx.path()
    let client_ip = ctx.client_ip()
    println("\{client_ip} [\{meth}] \{path} -> \{status} (\{elapsed}ms)")
  }
}
