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
/// CORS configuration.
pub(all) struct CORSConfig {
  allow_origins : Array[String]
  allow_methods : Array[String]
  allow_headers : Array[String]
  expose_headers : Array[String]
  allow_credentials : Bool
  max_age : Int
}

///|
/// Default CORS config (permissive).

pub fn CORSConfig::default() -> CORSConfig {
  {
    allow_origins: ["*"],
    allow_methods: ["GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS"],
    allow_headers: ["Origin", "Content-Type", "Accept", "Authorization"],
    expose_headers: ["Content-Length"],
    allow_credentials: false,
    max_age: 86400,
  }
}

///|
/// CORS middleware with custom configuration.
pub fn cors(config : CORSConfig) -> Handler {
  async fn(ctx) {
    // Set CORS headers
    let origin = match ctx.header("Origin") {
      Some(o) => o
      None => ""
    }
    let mut allowed = ""
    for o in config.allow_origins {
      if o == "*" || o == origin {
        allowed = origin
        break
      }
    }
    if allowed != "" {
      ctx.set_header("Access-Control-Allow-Origin", allowed)
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
    ctx.set_header("Access-Control-Max-Age", config.max_age.to_string())

    // Handle preflight
    if ctx.http_method() == "OPTIONS" {
      ctx.no_content()
      return
    }

    ctx.next()
  }
}
