///|
/// Secure headers middleware — adds common security headers to responses.
///
/// Security headers middleware, similar to helmet.
///
/// ## Usage
///
/// ```
/// app.use(secure(SecureConfig::default()))
/// ```

///|
/// Secure headers configuration.
pub(all) struct SecureConfig {
  /// X-Frame-Options: DENY | SAMEORIGIN | ALLOW-FROM uri
  /// Prevents clickjacking. Default: "DENY"
  frame_options : String
  /// X-Content-Type-Options: nosniff
  /// Prevents MIME type sniffing. Default: true
  content_type_nosniff : Bool
  /// X-XSS-Protection: 1; mode=block
  /// Enables browser XSS filter. Default: true
  xss_protection : Bool
  /// Content-Security-Policy header value.
  /// Example: "default-src 'self'"
  /// Empty = not set. Default: ""
  content_security_policy : String
  /// Referrer-Policy header value.
  /// Example: "strict-origin-when-cross-origin"
  /// Empty = not set. Default: "strict-origin-when-cross-origin"
  referrer_policy : String
  /// Strict-Transport-Security (HSTS) header value.
  /// Example: "max-age=31536000; includeSubDomains"
  /// Empty = not set. Default: ""
  strict_transport_security : String
  /// Permissions-Policy header (formerly Feature-Policy).
  /// Example: "camera=(), microphone=()"
  /// Empty = not set. Default: ""
  permissions_policy : String
  /// Cross-Origin-Opener-Policy header.
  /// Example: "same-origin"
  /// Empty = not set. Default: "same-origin"
  cross_origin_opener_policy : String
  /// Whether to set headers for API responses (skip HTML-only headers).
  /// When true, skips X-Frame-Options (not relevant for APIs).
  /// Default: false
  is_api : Bool
  /// Whether to skip HSTS header (useful for local development).
  /// Default: false
  skip_hsts : Bool
}

///|
/// Default secure configuration — balanced security for web applications.

pub fn SecureConfig::default() -> SecureConfig {
  {
    frame_options: "DENY",
    content_type_nosniff: true,
    xss_protection: true,
    content_security_policy: "",
    referrer_policy: "strict-origin-when-cross-origin",
    strict_transport_security: "",
    permissions_policy: "",
    cross_origin_opener_policy: "same-origin",
    is_api: false,
    skip_hsts: false,
  }
}

///|
/// Default secure configuration for APIs (no frame options, no CSP).
pub fn SecureConfig::api_default() -> SecureConfig {
  {
    frame_options: "",
    content_type_nosniff: true,
    xss_protection: true,
    content_security_policy: "",
    referrer_policy: "strict-origin-when-cross-origin",
    strict_transport_security: "",
    permissions_policy: "",
    cross_origin_opener_policy: "same-origin",
    is_api: true,
    skip_hsts: false,
  }
}

///|
/// Secure headers middleware.
///
/// ```
/// // Web app
/// app.use(secure(SecureConfig::default()))
///
/// // API server
/// app.use(secure(SecureConfig::api_default()))
/// ```
pub fn secure(config : SecureConfig) -> Handler {
  async fn(ctx) {
    // X-Frame-Options (skip for APIs)
    if config.frame_options != "" {
      ctx.set_header("X-Frame-Options", config.frame_options)
    }

    // X-Content-Type-Options
    if config.content_type_nosniff {
      ctx.set_header("X-Content-Type-Options", "nosniff")
    }

    // X-XSS-Protection
    if config.xss_protection {
      ctx.set_header("X-XSS-Protection", "1; mode=block")
    }

    // Content-Security-Policy
    if config.content_security_policy != "" {
      ctx.set_header("Content-Security-Policy", config.content_security_policy)
    }

    // Referrer-Policy
    if config.referrer_policy != "" {
      ctx.set_header("Referrer-Policy", config.referrer_policy)
    }

    // Strict-Transport-Security (HSTS)
    if config.strict_transport_security != "" && !config.skip_hsts {
      ctx.set_header(
        "Strict-Transport-Security",
        config.strict_transport_security,
      )
    }

    // Permissions-Policy
    if config.permissions_policy != "" {
      ctx.set_header("Permissions-Policy", config.permissions_policy)
    }

    // Cross-Origin-Opener-Policy
    if config.cross_origin_opener_policy != "" {
      ctx.set_header(
        "Cross-Origin-Opener-Policy",
        config.cross_origin_opener_policy,
      )
    }

    ctx.next()
  }
}
