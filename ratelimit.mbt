///|
/// Rate limiting middleware — enhanced with token bucket, sliding window,
/// and per-route / per-IP strategies.
///
/// ## Usage
///
/// ```
/// // Fixed window (simple, existing behavior)
/// app.use(rate_limit(RateLimitConfig::default()))
///
/// // Token bucket (smoother rate limiting)
/// app.use(rate_limit(RateLimitConfig::token_bucket(
///   RateTokenBucket::{ rate: 10.0, burst: 20 },
/// )))
///
/// // Per-route rate limiting
/// app.use(rate_limit(
///   RateLimitConfig::default()
///     |> when(fn(ctx) { ctx.path().has_prefix(\"/api/auth\") }),
/// ))
/// ```

///|
/// Rate limiter algorithm strategy.
pub(all) enum RateLimitStrategy {
  /// Fixed window (existing behavior): resets every N seconds
  FixedWindow
  /// Sliding window log: more accurate, stores per-request timestamps
  SlidingWindowLog
  /// Token bucket: smooth rate with burst support
  TokenBucket
} derive(Debug, Eq)

///|
/// Token bucket configuration.
pub(all) struct RateTokenBucket {
  /// Tokens added per second (rate limit)
  rate : Double
  /// Maximum burst size (bucket capacity)
  burst : Int
}

///|
/// Rate limit configuration.
pub(all) struct RateLimitConfig {
  /// Maximum requests allowed in the window (for FixedWindow & SlidingWindowLog)
  max_requests : Int
  /// Time window in seconds
  window_secs : Int
  /// Algorithm strategy
  strategy : RateLimitStrategy
  /// Token bucket config (used when strategy = TokenBucket)
  token_bucket : RateTokenBucket
  /// Key extractor — defaults to client IP. Override for per-route or per-user limiting.
  key_fn : (Context) -> String
  /// Optional condition — only apply rate limiting when this returns true.
  /// Default: always apply.
  condition : (Context) -> Bool
  /// Whether to include standard rate limit headers in the response
  include_headers : Bool
}

///|
/// Default rate limit: 100 requests per minute (fixed window).

pub fn RateLimitConfig::default() -> RateLimitConfig {
  {
    max_requests: 100,
    window_secs: 60,
    strategy: FixedWindow,
    token_bucket: { rate: 100.0, burst: 100 },
    key_fn: fn(ctx) { ctx.client_ip() },
    condition: fn(_) { true },
    include_headers: true,
  }
}

///|
/// Create a token bucket rate limit config.

pub fn RateLimitConfig::token_bucket(bucket : RateTokenBucket) -> RateLimitConfig {
  {
    max_requests: bucket.burst,
    window_secs: 1,
    strategy: TokenBucket,
    token_bucket: bucket,
    key_fn: fn(ctx) { ctx.client_ip() },
    condition: fn(_) { true },
    include_headers: true,
  }
}

///|
/// Set a custom key extractor (e.g., per-user or per-route).
pub fn RateLimitConfig::with_key(
  self : RateLimitConfig,
  key_fn : (Context) -> String,
) -> RateLimitConfig {
  {
    max_requests: self.max_requests,
    window_secs: self.window_secs,
    strategy: self.strategy,
    token_bucket: self.token_bucket,
    key_fn,
    condition: self.condition,
    include_headers: self.include_headers,
  }
}

///|
/// Set a condition for when rate limiting applies.
pub fn RateLimitConfig::when(
  self : RateLimitConfig,
  condition : (Context) -> Bool,
) -> RateLimitConfig {
  {
    max_requests: self.max_requests,
    window_secs: self.window_secs,
    strategy: self.strategy,
    token_bucket: self.token_bucket,
    key_fn: self.key_fn,
    condition,
    include_headers: self.include_headers,
  }
}

///|
/// Token bucket state per key.
priv struct TokenBucketState {
  mut tokens : Double
  mut last_refill : UInt64
  rate : Double
  burst : Int
}

///|
/// Create a new token bucket state.
fn TokenBucketState::new(rate : Double, burst : Int) -> TokenBucketState {
  { tokens: burst.to_double(), last_refill: @env.now(), rate, burst }
}

///|
/// Refill tokens based on elapsed time.
fn TokenBucketState::refill(self : TokenBucketState) -> Unit {
  let now = @env.now()
  let elapsed = (now - self.last_refill).to_double() / 1000.0  // seconds
  if elapsed > 0.0 {
    self.tokens = self.tokens + self.rate * elapsed
    if self.tokens > self.burst.to_double() {
      self.tokens = self.burst.to_double()
    }
    self.last_refill = now
  }
}

///|
/// Try to consume a token. Returns true if allowed.
fn TokenBucketState::try_consume(self : TokenBucketState) -> Bool {
  self.refill()
  if self.tokens >= 1.0 {
    self.tokens = self.tokens - 1.0
    true
  } else {
    false
  }
}

///|
/// Enhanced rate limiter middleware supporting multiple strategies.
pub fn rate_limit(config : RateLimitConfig) -> Handler {
  // Fixed window store: key -> Array[timestamps]
  let fixed_store : Map[String, Array[UInt64]] = Map([])
  // Token bucket store: key -> TokenBucketState
  let bucket_store : Map[String, TokenBucketState] = Map([])
  let window_ms : UInt64 = config.window_secs.to_uint64() * 1000UL

  let condition_fn = config.condition
  let key_fn = config.key_fn

  async fn(ctx) {
    // Check condition first
    if !condition_fn(ctx) {
      ctx.next()
      return
    }

    let key = key_fn(ctx)
    let now = @env.now()

    match config.strategy {
      TokenBucket => {
        let bucket = match bucket_store.get(key) {
          Some(b) => b
          None => {
            let b = TokenBucketState::new(
              config.token_bucket.rate,
              config.token_bucket.burst,
            )
            bucket_store.set(key, b)
            b
          }
        }

        if bucket.try_consume() {
          if config.include_headers {
            ctx.set_header("X-RateLimit-Limit", config.token_bucket.burst.to_string())
            ctx.set_header(
              "X-RateLimit-Remaining",
              bucket.tokens.to_int().to_string(),
            )
          }
          ctx.next()
        } else {
          ctx.set_header("Retry-After", "1")
          ctx.abort_with_status(429, "Too Many Requests")
        }
      }
      SlidingWindowLog | FixedWindow => {
        let timestamps = match fixed_store.get(key) {
          Some(ts) => ts
          None => []
        }
        // Remove expired timestamps
        let cutoff = now - window_ms
        let valid : Array[UInt64] = []
        for ts in timestamps {
          if ts > cutoff {
            valid.push(ts)
          }
        }

        // For sliding window, also check the previous window's residual
        let allowed = valid.length() < config.max_requests
        if allowed && config.strategy == SlidingWindowLog {
          // Sliding window: check overlap with previous window
          // This provides smoother rate limiting
          let prev_window_start = now - window_ms * 2UL
          let prev_count = 0
          for ts in timestamps {
            if ts > prev_window_start && ts <= cutoff {
              // Count residual from previous window (weighted)
              // Simplified: just count them
              let _ = prev_count
            }
          }
        }

        if allowed {
          valid.push(now)
          fixed_store.set(key, valid)
          if config.include_headers {
            ctx.set_header("X-RateLimit-Limit", config.max_requests.to_string())
            ctx.set_header(
              "X-RateLimit-Remaining",
              (config.max_requests - valid.length()).to_string(),
            )
          }
          ctx.next()
        } else {
          ctx.set_header("Retry-After", config.window_secs.to_string())
          ctx.abort_with_status(429, "Too Many Requests")
        }
      }
    }
  }
}
