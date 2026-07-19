///|
/// Rate limiting middleware — simple in-memory rate limiter based on client IP.
///
/// Usage:
/// ```
/// app.use(rate_limit(RateLimitConfig::{ max_requests: 50, window_secs: 60 }))
/// ```

///|
/// Rate limit configuration.
pub(all) struct RateLimitConfig {
  /// Maximum requests allowed in the window
  max_requests : Int
  /// Time window in seconds
  window_secs : Int
}

///|
/// Default rate limit: 100 requests per minute.

pub fn RateLimitConfig::default() -> RateLimitConfig {
  { max_requests: 100, window_secs: 60 }
}

///|
/// Simple in-memory rate limiter based on client IP.
pub fn rate_limit(config : RateLimitConfig) -> Handler {
  let store : Map[String, Array[Int64]] = {}
  let window_ms : Int64 = config.window_secs.to_int64() * 1000L
  fn(ctx) {
    let ip = ctx.client_ip()
    let now = @async.now()
    let timestamps = match store.get(ip) {
      Some(ts) => ts
      None => []
    }
    // Remove expired timestamps
    let cutoff = now - window_ms
    let valid : Array[Int64] = []
    for ts in timestamps {
      if ts > cutoff {
        valid.push(ts)
      }
    }
    if valid.length() >= config.max_requests {
      ctx.set_header("Retry-After", config.window_secs.to_string())
      ctx.abort_with_status(429, "Too Many Requests")
      return
    }
    valid.push(now)
    store.set(ip, valid)
    ctx.set_header("X-RateLimit-Limit", config.max_requests.to_string())
    ctx.set_header(
      "X-RateLimit-Remaining",
      (config.max_requests - valid.length()).to_string(),
    )
    ctx.next()
  }
}
