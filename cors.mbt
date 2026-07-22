///|
/// CORS middleware with custom configuration.
///
/// Standard `cors` middleware.
///
/// Usage:
/// ```
/// app.use(cors(CORSConfig::default()))
/// ```

///|
/// CORS configuration with dynamic origin support.
pub(all) struct CORSConfig {
  /// Static list of allowed origins. Supports `*` wildcard.
  allow_origins : Array[String]
  /// Dynamic origin validator — called for each request when set.
  /// When set (non-None return), `allow_origins` is ignored for validation.
  /// Returns true if origin is allowed, false if denied, None to fall back.
  allow_origin_fn : (String) -> Bool?
  allow_methods : Array[String]
  allow_headers : Array[String]
  expose_headers : Array[String]
  allow_credentials : Bool
  max_age : Int
  /// Whether to add the Vary: Origin header
  vary_origin : Bool
  /// Whether to allow private network access (PNA) headers
  allow_private_network : Bool
}

///|
/// Default CORS config (permissive).

pub fn CORSConfig::default() -> CORSConfig {
  {
    allow_origins: ["*"],
    allow_origin_fn: fn(_) { None },
    allow_methods: ["GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS"],
    allow_headers: ["Origin", "Content-Type", "Accept", "Authorization"],
    expose_headers: ["Content-Length"],
    allow_credentials: false,
    max_age: 86400,
    vary_origin: true,
    allow_private_network: false,
  }
}

///|
/// Create a CORS config with a dynamic origin validator.
/// The validator function receives the Origin header and returns true if allowed.
///
/// ```
/// let cfg = CORSConfig::with_origin_fn(fn(origin) {
///   origin.has_suffix(".mydomain.com") || origin == "https://app.mydomain.com"
/// })
/// app.use(cors(cfg))
/// ```
pub fn CORSConfig::with_origin_fn(
  allow_origin_fn : (String) -> Bool,
) -> CORSConfig {
  {
    allow_origins: ["*"],
    allow_origin_fn: fn(origin) { Some(allow_origin_fn(origin)) },
    allow_methods: ["GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS"],
    allow_headers: ["Origin", "Content-Type", "Accept", "Authorization"],
    expose_headers: ["Content-Length"],
    allow_credentials: false,
    max_age: 86400,
    vary_origin: true,
    allow_private_network: false,
  }
}

///|
/// CORS middleware with custom configuration.
pub fn cors(config : CORSConfig) -> Handler {
  async fn(ctx) {
    let origin = match ctx.header("Origin") {
      Some(o) => o
      None => {
        // No Origin header — pass through for same-origin requests
        ctx.next()
        return
      }
    }

    // Determine if origin is allowed
    let dynamic_result = (config.allow_origin_fn)(origin)
    let allowed = match dynamic_result {
      Some(result) => result
      None => {
        // Fall back to static origins list
        let mut matched = false
        for o in config.allow_origins {
          if o == "*" || o == origin {
            matched = true
            break
          }
        }
        matched
      }
    }

    if allowed {
      // For credentialed requests, must echo back exact origin (not *)
      let use_wildcard = config.allow_origins.length() == 1 && config.allow_origins[0] == "*"
      let response_origin = if use_wildcard && !config.allow_credentials {
        "*"
      } else {
        origin
      }
      ctx.set_header("Access-Control-Allow-Origin", response_origin)

      if config.vary_origin {
        ctx.set_header("Vary", "Origin")
      }

      ctx.set_header(
        "Access-Control-Allow-Methods",
        join_strings(config.allow_methods, ", "),
      )
      ctx.set_header(
        "Access-Control-Allow-Headers",
        join_strings(config.allow_headers, ", "),
      )
      ctx.set_header(
        "Access-Control-Expose-Headers",
        join_strings(config.expose_headers, ", "),
      )

      if config.allow_credentials {
        ctx.set_header("Access-Control-Allow-Credentials", "true")
      }
      if config.max_age > 0 {
        ctx.set_header("Access-Control-Max-Age", config.max_age.to_string())
      }
      if config.allow_private_network {
        ctx.set_header("Access-Control-Allow-Private-Network", "true")
      }

      // Handle preflight
      if ctx.http_method() == "OPTIONS" {
        ctx.no_content()
        return
      }

      ctx.next()
    } else {
      // Origin not allowed — still pass through but without CORS headers
      ctx.next()
    }
  }
}
