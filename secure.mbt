///|
/// Secure headers middleware — adds common security headers and CSRF protection.
///
/// Security headers middleware, similar to helmet, with CSRF token support.
///
/// ## Usage
///
/// ```
/// // Security headers only
/// app.use(secure(SecureConfig::default()))
///
/// // With CSRF protection
/// app.use(secure(SecureConfig::default().with_csrf()))
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
  /// === CSRF Protection ===
  /// Enable CSRF token validation
  enable_csrf : Bool
  /// CSRF token secret (used to sign tokens). Auto-generated if empty.
  csrf_secret : String
  /// CSRF cookie name. Default: "_csrf"
  csrf_cookie_name : String
  /// CSRF header name to check. Default: "X-CSRF-Token"
  csrf_header_name : String
  /// CSRF form field name to check. Default: "_csrf"
  csrf_form_name : String
  /// HTTP methods that are safe (no CSRF check). Default: GET, HEAD, OPTIONS, TRACE
  safe_methods : Array[String]
  /// Paths to exclude from CSRF protection
  csrf_exclude_paths : Array[String]
  /// CSRF token expiry in seconds. Default: 86400 (24h)
  csrf_token_expiry : Int
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
    enable_csrf: false,
    csrf_secret: "",
    csrf_cookie_name: "_csrf",
    csrf_header_name: "X-CSRF-Token",
    csrf_form_name: "_csrf",
    safe_methods: ["GET", "HEAD", "OPTIONS", "TRACE"],
    csrf_exclude_paths: [],
    csrf_token_expiry: 86400,
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
    enable_csrf: false,
    csrf_secret: "",
    csrf_cookie_name: "_csrf",
    csrf_header_name: "X-CSRF-Token",
    csrf_form_name: "_csrf",
    safe_methods: ["GET", "HEAD", "OPTIONS", "TRACE"],
    csrf_exclude_paths: [],
    csrf_token_expiry: 86400,
  }
}

///|
/// Enable CSRF protection on this config.
pub fn SecureConfig::with_csrf(self : SecureConfig) -> SecureConfig {
  {
    frame_options: self.frame_options,
    content_type_nosniff: self.content_type_nosniff,
    xss_protection: self.xss_protection,
    content_security_policy: self.content_security_policy,
    referrer_policy: self.referrer_policy,
    strict_transport_security: self.strict_transport_security,
    permissions_policy: self.permissions_policy,
    cross_origin_opener_policy: self.cross_origin_opener_policy,
    is_api: self.is_api,
    skip_hsts: self.skip_hsts,
    enable_csrf: true,
    csrf_secret: self.csrf_secret,
    csrf_cookie_name: self.csrf_cookie_name,
    csrf_header_name: self.csrf_header_name,
    csrf_form_name: self.csrf_form_name,
    safe_methods: self.safe_methods,
    csrf_exclude_paths: self.csrf_exclude_paths,
    csrf_token_expiry: self.csrf_token_expiry,
  }
}

///|
/// Set a custom CSRF secret.
pub fn SecureConfig::with_csrf_secret(self : SecureConfig, secret : String) -> SecureConfig {
  {
    frame_options: self.frame_options,
    content_type_nosniff: self.content_type_nosniff,
    xss_protection: self.xss_protection,
    content_security_policy: self.content_security_policy,
    referrer_policy: self.referrer_policy,
    strict_transport_security: self.strict_transport_security,
    permissions_policy: self.permissions_policy,
    cross_origin_opener_policy: self.cross_origin_opener_policy,
    is_api: self.is_api,
    skip_hsts: self.skip_hsts,
    enable_csrf: self.enable_csrf,
    csrf_secret: secret,
    csrf_cookie_name: self.csrf_cookie_name,
    csrf_header_name: self.csrf_header_name,
    csrf_form_name: self.csrf_form_name,
    safe_methods: self.safe_methods,
    csrf_exclude_paths: self.csrf_exclude_paths,
    csrf_token_expiry: self.csrf_token_expiry,
  }
}

///|
/// Add paths to exclude from CSRF protection.
pub fn SecureConfig::with_csrf_exclude(
  self : SecureConfig,
  paths : Array[String],
) -> SecureConfig {
  {
    frame_options: self.frame_options,
    content_type_nosniff: self.content_type_nosniff,
    xss_protection: self.xss_protection,
    content_security_policy: self.content_security_policy,
    referrer_policy: self.referrer_policy,
    strict_transport_security: self.strict_transport_security,
    permissions_policy: self.permissions_policy,
    cross_origin_opener_policy: self.cross_origin_opener_policy,
    is_api: self.is_api,
    skip_hsts: self.skip_hsts,
    enable_csrf: self.enable_csrf,
    csrf_secret: self.csrf_secret,
    csrf_cookie_name: self.csrf_cookie_name,
    csrf_header_name: self.csrf_header_name,
    csrf_form_name: self.csrf_form_name,
    safe_methods: self.safe_methods,
    csrf_exclude_paths: paths,
    csrf_token_expiry: self.csrf_token_expiry,
  }
}

///|
/// Generate a CSRF token based on session and secret.
fn generate_csrf_token(secret : String, now : UInt64) -> String {
  // Simplified CSRF token: timestamp + hash(secret + timestamp)
  // In production, use @encoding.base64 + @hash.sha256
  let timestamp = now.to_string()
  let raw = secret + ":" + timestamp
  let hash_val = simple_token_hash(raw)
  timestamp + ":" + hash_val
}

///|
/// Simple token hash for CSRF.
fn simple_token_hash(s : String) -> String {
  let mut h : Int64 = 5381L
  let chars = s.to_array()
  for i = 0; i < chars.length(); i = i + 1 {
    let byte_val = chars[i].to_int().to_int64()
    h = ((h << 5) + h) + byte_val
  }
  h.to_string()
}

///|
/// Validate a CSRF token.
fn validate_csrf_token(token : String, secret : String, max_age : Int) -> Bool {
  match token.find(":") {
    Some(pos) => {
      let timestamp_str = token[:pos].to_owned()
      let hash_val = token[pos + 1:].to_owned()
      let expected = simple_token_hash(secret + ":" + timestamp_str)
      if hash_val != expected {
        return false
      }
      // Check expiry
      let token_time = @string.parse_int64(timestamp_str) catch { _ => return false }
      let now = @env.now().reinterpret_as_int64()
      if now - token_time > max_age.to_int64() {
        return false
      }
      true
    }
    None => false
  }
}

///|
/// Check if a path should be excluded from CSRF protection.
fn is_csrf_excluded(path : String, exclude_paths : Array[String]) -> Bool {
  for p in exclude_paths {
    if path == p || path.has_prefix(p) {
      return true
    }
  }
  false
}

///|
/// Secure headers middleware with optional CSRF protection.
///
/// ```
/// // Web app
/// app.use(secure(SecureConfig::default()))
///
/// // With CSRF protection
/// app.use(secure(SecureConfig::default().with_csrf()))
///
/// // API server
/// app.use(secure(SecureConfig::api_default()))
/// ```
pub fn secure(config : SecureConfig) -> Handler {
  // Generate a default secret if none provided
  let secret = if config.csrf_secret == "" {
    @env.now().to_string() + "_mbit_csrf"
  } else {
    config.csrf_secret
  }

  async fn(ctx) {
    // === Security Headers ===
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

    // === CSRF Protection ===
    if config.enable_csrf {
      let path = ctx.path()

      // Skip excluded paths
      if !is_csrf_excluded(path, config.csrf_exclude_paths) {
        let _method = ctx.http_method()

        // Check if this is a safe method
        let mut is_safe = false
        for safe in config.safe_methods {
          if safe == _method {
            is_safe = true
            break
          }
        }

        if is_safe {
          // For safe methods, generate and set CSRF cookie
          let token = generate_csrf_token(secret, @env.now())
          ctx.set_cookie(
            config.csrf_cookie_name,
            token,
            http_only=true,
            same_site="Strict",
            secure=true,
            path="/",
          )
          // Store token in context for template rendering
          ctx.set("csrf_token", Json::string(token))
        } else {
          // For unsafe methods, validate CSRF token
          // Check header first, then form field
          let csrf_token = match ctx.header(config.csrf_header_name) {
            Some(t) => Some(t)
            None => {
              // Try form field
              let form = ctx.body_string()
              let field_prefix = config.csrf_form_name + "="
              match form.find(field_prefix) {
                Some(start) => {
                  let after = start + field_prefix.length()
                  match form[after:].find("&") {
                    Some(end) => Some(form[after:after + end].to_owned())
                    None => Some(form[after:].to_owned())
                  }
                }
                None => None
              }
            }
          }

          match csrf_token {
            Some(token) => {
              if !validate_csrf_token(token, secret, config.csrf_token_expiry) {
                ctx.abort_with_status(403, "CSRF token invalid or expired")
                return
              }
            }
            None => {
              ctx.abort_with_status(403, "CSRF token missing")
              return
            }
          }
        }
      }
    }

    ctx.next()
  }
}
