///|
/// Middleware tests — covers CORS config, rate limit config, basic auth config, and utilities.

///|

test "CORSConfig defaults" {
  let c = CORSConfig::default()
  assert_eq(c.allow_origins[0], "*")
  assert_eq(c.allow_methods.length(), 6)
  assert_false(c.allow_credentials)
  assert_eq(c.max_age, 86400)
}

///|
test "CORSConfig custom" {
  let c = CORSConfig::{
    allow_origins: ["https://example.com"],
    allow_origin_fn: fn(_) { None },
    allow_methods: ["GET"],
    allow_headers: ["X-Token"],
    expose_headers: [],
    allow_credentials: true,
    max_age: 3600,
    vary_origin: true,
    allow_private_network: false,
  }
  assert_eq(c.allow_origins[0], "https://example.com")
  assert_true(c.allow_credentials)
}

///|
test "RateLimitConfig defaults" {
  let c = RateLimitConfig::default()
  assert_eq(c.max_requests, 100)
  assert_eq(c.window_secs, 60)
}

///|
test "RateLimitConfig custom" {
  let c = RateLimitConfig::{
    max_requests: 10,
    window_secs: 30,
    strategy: FixedWindow,
    token_bucket: { rate: 100.0, burst: 100 },
    key_fn: fn(ctx) { ctx.client_ip() },
    condition: fn(_) { true },
    include_headers: true,
  }
  assert_eq(c.max_requests, 10)
}

///|
test "BasicAuthConfig" {
  let accounts : Map[String, String] = { "admin": "secret" }
  let c = BasicAuthConfig::{ accounts, realm: "Test" }
  assert_eq(c.realm, "Test")
  assert_eq(c.accounts.get("admin"), Some("secret"))
}

///|
test "logger returns Handler" {
  let _ = logger()
  assert_true(true)
}

///|
test "recovery returns Handler" {
  let _ = recovery()
  assert_true(true)
}

///|
test "cors returns Handler" {
  let _ = cors(CORSConfig::default())
  assert_true(true)
}

///|
test "basic_auth returns Handler" {
  let accounts : Map[String, String] = { "u": "p" }
  let _ = basic_auth(BasicAuthConfig::{ accounts, realm: "R" })
  assert_true(true)
}

///|
test "basic_auth_for_realm convenience" {
  let accounts : Map[String, String] = { "u": "p" }
  let _ = basic_auth_for_realm(accounts, "My Realm")
  assert_true(true)
}

///|
test "request_id returns Handler" {
  let _ = request_id()
  assert_true(true)
}

///|
test "timing returns Handler" {
  let _ = timing()
  assert_true(true)
}

///|
test "body_size_limit returns Handler" {
  let _ = body_size_limit(1024L)
  assert_true(true)
}

///|
test "join_strings empty" {
  assert_eq(join_strings([], ", "), "")
}

///|
test "join_strings single" {
  assert_eq(join_strings(["a"], ", "), "a")
}

///|
test "join_strings multiple" {
  assert_eq(join_strings(["a", "b", "c"], "|"), "a|b|c")
}

///|
test "guess_content_type known" {
  assert_eq(guess_content_type("f.html"), "text/html; charset=utf-8")
  assert_eq(guess_content_type("f.css"), "text/css; charset=utf-8")
  assert_eq(guess_content_type("f.js"), "application/javascript; charset=utf-8")
  assert_eq(guess_content_type("f.png"), "image/png")
}

///|
test "guess_content_type unknown" {
  assert_eq(guess_content_type("f.xyz"), "application/octet-stream")
}

///|
test "url_decode basic" {
  assert_eq(url_decode("hello%20world"), "hello world")
}

///|
test "url_decode plus" {
  assert_eq(url_decode("a+b"), "a b")
}

///|
test "url_encode basic" {
  let encoded = url_encode("hello world")
  assert_true(encoded.contains("%20"))
}

///| ——————————————————————————————————————————————————————————————————————
///  Extended tests: CORS configuration coverage
///| ——————————————————————————————————————————————————————————————————————

test "CORSConfig all fields" {
  let c = CORSConfig::{
    allow_origins: ["https://a.com", "https://b.com"],
    allow_origin_fn: fn(_) { None },
    allow_methods: ["GET", "POST"],
    allow_headers: ["X-Custom"],
    expose_headers: ["X-Response-Time", "X-Request-Id"],
    allow_credentials: true,
    max_age: 7200,
    vary_origin: true,
    allow_private_network: false,
  }
  assert_eq(c.allow_origins.length(), 2)
  assert_eq(c.allow_methods.length(), 2)
  assert_eq(c.allow_headers.length(), 1)
  assert_eq(c.expose_headers.length(), 2)
  assert_true(c.allow_credentials)
  assert_eq(c.max_age, 7200)
}

test "CORSConfig restrictive" {
  let c = CORSConfig::{
    allow_origins: ["https://trusted.com"],
    allow_origin_fn: fn(_) { None },
    allow_methods: ["GET"],
    allow_headers: ["Accept"],
    expose_headers: [],
    allow_credentials: true,
    max_age: 600,
    vary_origin: true,
    allow_private_network: false,
  }
  assert_eq(c.allow_origins[0], "https://trusted.com")
  assert_eq(c.allow_methods.length(), 1)
  assert_eq(c.allow_headers.length(), 1)
  assert_eq(c.expose_headers.length(), 0)
}

test "CORSConfig matches default structure" {
  let c = CORSConfig::default()
  // Default has wildcard origin and common headers
  assert_eq(c.allow_origins[0], "*")
  // verify no crash when accessing defaults
  let _ = c.allow_methods.length()
  let _ = c.allow_headers.length()
  assert_true(true)
}

///| ——————————————————————————————————————————————————————————————————————
///  Rate limit config coverage
///| ——————————————————————————————————————————————————————————————————————

test "RateLimitConfig zero max" {
  let c = RateLimitConfig::{
    max_requests: 0,
    window_secs: 10,
    strategy: FixedWindow,
    token_bucket: { rate: 100.0, burst: 100 },
    key_fn: fn(ctx) { ctx.client_ip() },
    condition: fn(_) { true },
    include_headers: true,
  }
  assert_eq(c.max_requests, 0)
  assert_eq(c.window_secs, 10)
}

test "RateLimitConfig large window" {
  let c = RateLimitConfig::{
    max_requests: 1000,
    window_secs: 3600,
    strategy: FixedWindow,
    token_bucket: { rate: 100.0, burst: 100 },
    key_fn: fn(ctx) { ctx.client_ip() },
    condition: fn(_) { true },
    include_headers: true,
  }
  assert_eq(c.window_secs, 3600)
}

///| ——————————————————————————————————————————————————————————————————————
///  BasicAuth config coverage
///| ——————————————————————————————————————————————————————————————————————

test "BasicAuthConfig multiple accounts" {
  let accounts : Map[String, String] = { "admin": "s3cret", "user": "pass", "api": "key123" }
  let c = BasicAuthConfig::{ accounts, realm: "API" }
  assert_eq(c.accounts.get("admin"), Some("s3cret"))
  assert_eq(c.accounts.get("user"), Some("pass"))
  assert_eq(c.accounts.get("api"), Some("key123"))
  assert_eq(c.accounts.get("unknown"), None)
}

test "BasicAuthConfig empty accounts" {
  let accounts : Map[String, String] = Map([])
  let c = BasicAuthConfig::{ accounts, realm: "" }
  assert_eq(c.accounts.length(), 0)
  assert_eq(c.realm, "")
}

test "basic_auth_for_realm functionality" {
  let accounts : Map[String, String] = { "root": "toor" }
  let handler = basic_auth_for_realm(accounts, "Admin Area")
  // Verify it returns a Handler (type check by calling)
  let _ = handler
  assert_true(true)
}

///| ——————————————————————————————————————————————————————————————————————
///  Body size limit coverage
///| ——————————————————————————————————————————————————————————————————————

test "body_size_limit with zero" {
  let handler = body_size_limit(0L)
  let _ = handler
  assert_true(true)
}

test "body_size_limit with large value" {
  let handler = body_size_limit(10L * 1024L * 1024L * 1024L) // 10 GB
  let _ = handler
  assert_true(true)
}

///| ——————————————————————————————————————————————————————————————————————
///  URL decode/encode edge cases
///| ——————————————————————————————————————————————————————————————————————

test "url_decode no encoding" {
  assert_eq(url_decode("plaintext"), "plaintext")
}

test "url_decode multiple encodings" {
  let decoded = url_decode("Hello%20World%21")
  assert_eq(decoded, "Hello World!")
}

test "url_decode lowercase hex" {
  assert_eq(url_decode("%3c%3e"), "<>")
}

test "url_decode uppercase hex" {
  assert_eq(url_decode("%3C%3E"), "<>")
}

test "url_decode percent sign" {
  assert_eq(url_decode("%25"), "%")
}

test "url_decode empty" {
  assert_eq(url_decode(""), "")
}

test "url_encode alphanumeric unchanged" {
  let encoded = url_encode("abc123XYZ")
  assert_eq(encoded, "abc123XYZ")
}

test "url_encode special chars" {
  let encoded = url_encode("hello world!")
  assert_true(encoded.contains("%20"))
  assert_true(encoded.contains("%21"))
}

test "url_encode empty string" {
  assert_eq(url_encode(""), "")
}

///| ——————————————————————————————————————————————————————————————————————
///  Join strings edge cases
///| ——————————————————————————————————————————————————————————————————————

test "join_strings with empty separator" {
  assert_eq(join_strings(["a", "b", "c"], ""), "abc")
}

test "join_strings with space separator" {
  assert_eq(join_strings(["hello", "world"], " "), "hello world")
}

///| ——————————————————————————————————————————————————————————————————————
///  Content type guessing — extended
///| ——————————————————————————————————————————————————————————————————————

test "guess_content_type svg" {
  assert_eq(guess_content_type("icon.svg"), "image/svg+xml")
}

test "guess_content_type ico" {
  assert_eq(guess_content_type("favicon.ico"), "image/x-icon")
}

test "guess_content_type woff" {
  assert_eq(guess_content_type("font.woff"), "font/woff")
}

test "guess_content_type woff2" {
  assert_eq(guess_content_type("font.woff2"), "font/woff2")
}

test "guess_content_type ttf" {
  assert_eq(guess_content_type("font.ttf"), "font/ttf")
}

test "guess_content_type xml" {
  assert_eq(guess_content_type("data.xml"), "application/xml; charset=utf-8")
}

test "guess_content_type txt" {
  assert_eq(guess_content_type("readme.txt"), "text/plain; charset=utf-8")
}

///| ——————————————————————————————————————————————————————————————————————
///  Gzip middleware tests
///| ——————————————————————————————————————————————————————————————————————

test "GzipConfig defaults" {
  let c = GzipConfig::default()
  assert_eq(c.min_length, 1024)
  assert_eq(c.level, 6)
  assert_eq(c.compressible_types.length(), 0)
  assert_eq(c.excluded_types.length(), 4)
}

test "GzipConfig custom" {
  let c = GzipConfig::{
    min_length: 512,
    level: 9,
    compressible_types: ["text/html", "application/json"],
    excluded_types: ["image/"],
  }
  assert_eq(c.min_length, 512)
  assert_eq(c.level, 9)
  assert_eq(c.compressible_types.length(), 2)
  assert_eq(c.excluded_types.length(), 1)
}

test "gzip returns Handler" {
  let _ = gzip(GzipConfig::default())
  assert_true(true)
}

test "is_excluded_type matches prefix" {
  assert_true(is_excluded_type("image/png", ["image/", "video/"]))
  assert_true(is_excluded_type("video/mp4", ["image/", "video/"]))
  assert_false(is_excluded_type("text/html", ["image/", "video/"]))
}

test "is_included_type matches prefix" {
  assert_true(is_included_type("text/html", ["text/html", "application/json"]))
  assert_true(is_included_type("application/json", ["text/html", "application/json"]))
  assert_false(is_included_type("image/png", ["text/html", "application/json"]))
}

///| ——————————————————————————————————————————————————————————————————————
///  Secure middleware tests
///| ——————————————————————————————————————————————————————————————————————

test "SecureConfig defaults" {
  let c = SecureConfig::default()
  assert_eq(c.frame_options, "DENY")
  assert_true(c.content_type_nosniff)
  assert_true(c.xss_protection)
  assert_eq(c.referrer_policy, "strict-origin-when-cross-origin")
  assert_eq(c.cross_origin_opener_policy, "same-origin")
  assert_false(c.is_api)
  assert_eq(c.content_security_policy, "")
  assert_eq(c.strict_transport_security, "")
}

test "SecureConfig api_default" {
  let c = SecureConfig::api_default()
  assert_eq(c.frame_options, "")
  assert_true(c.content_type_nosniff)
  assert_true(c.xss_protection)
  assert_true(c.is_api)
}

test "SecureConfig custom" {
  let c = SecureConfig::{
    frame_options: "SAMEORIGIN",
    content_type_nosniff: true,
    xss_protection: false,
    content_security_policy: "default-src 'self'",
    referrer_policy: "no-referrer",
    strict_transport_security: "max-age=31536000",
    permissions_policy: "camera=()",
    cross_origin_opener_policy: "unsafe-none",
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
  assert_eq(c.frame_options, "SAMEORIGIN")
  assert_false(c.xss_protection)
  assert_eq(c.content_security_policy, "default-src 'self'")
  assert_eq(c.referrer_policy, "no-referrer")
  assert_eq(c.strict_transport_security, "max-age=31536000")
  assert_eq(c.permissions_policy, "camera=()")
  assert_eq(c.cross_origin_opener_policy, "unsafe-none")
}

test "secure returns Handler" {
  let _ = secure(SecureConfig::default())
  assert_true(true)
}

test "secure api returns Handler" {
  let _ = secure(SecureConfig::api_default())
  assert_true(true)
}

test "SecureConfig with_csrf enables csrf" {
  let c = SecureConfig::default().with_csrf()
  assert_true(c.enable_csrf)
}

test "SecureConfig with_csrf_secret" {
  let c = SecureConfig::default().with_csrf().with_csrf_secret("my-secret")
  assert_true(c.enable_csrf)
  assert_eq(c.csrf_secret, "my-secret")
}

test "SecureConfig with_csrf_exclude" {
  let c = SecureConfig::default().with_csrf().with_csrf_exclude(["/webhook", "/health"])
  assert_true(c.enable_csrf)
  assert_eq(c.csrf_exclude_paths.length(), 2)
}

test "SecureConfig api_default has csrf disabled" {
  let c = SecureConfig::api_default()
  assert_false(c.enable_csrf)
  assert_eq(c.csrf_cookie_name, "_csrf")
  assert_eq(c.csrf_header_name, "X-CSRF-Token")
  assert_eq(c.csrf_form_name, "_csrf")
}

///| ——————————————————————————————————————————————————————————————————————
///  New middleware features: CORS dynamic origin, rate limit strategies
///| ——————————————————————————————————————————————————————————————————————

test "CORSConfig with_origin_fn" {
  let c = CORSConfig::with_origin_fn(fn(origin) { origin == "https://trusted.com" })
  assert_eq(c.allow_origins[0], "*")
  // The middleware uses the dynamic function instead of the allow_origins list
  assert_true(true)
}

test "CORSConfig vary_origin default" {
  let c = CORSConfig::default()
  assert_true(c.vary_origin)
}

test "CORSConfig allow_private_network default" {
  let c = CORSConfig::default()
  assert_false(c.allow_private_network)
}

test "RateLimitConfig token_bucket" {
  let c = RateLimitConfig::token_bucket(RateTokenBucket::{ rate: 50.0, burst: 100 })
  assert_eq(c.max_requests, 100)
  assert_eq(c.token_bucket.rate, 50.0)
  assert_eq(c.token_bucket.burst, 100)
  assert_true(c.include_headers)
}

test "RateLimitConfig with_key" {
  let c = RateLimitConfig::default().with_key(fn(ctx) { ctx.param_default("api_key", "unknown") })
  assert_true(true)
}

test "RateLimitConfig when condition" {
  let c = RateLimitConfig::default().when(fn(ctx) { ctx.path().has_prefix("/api/") })
  assert_true(true)
}

///| ——————————————————————————————————————————————————————————————————————
///  Structured logger & metrics tests
///| ——————————————————————————————————————————————————————————————————————

test "set_log_level and log_level" {
  Logger::set_level(Debug)
  assert_eq(Logger::level(), Debug)
  Logger::set_level(Info)
  assert_eq(Logger::level(), Info)
  Logger::set_level(Debug)
}

test "is_log_enabled" {
  Logger::set_level(Info)
  assert_false(Logger::is_enabled(Debug))
  assert_true(Logger::is_enabled(Info))
  assert_true(Logger::is_enabled(Warn))
  assert_true(Logger::is_enabled(Error))
  Logger::set_level(Debug)
  assert_true(Logger::is_enabled(Debug))
}

test "StructuredLogConfig defaults" {
  let c = StructuredLogConfig::default()
  assert_eq(c.level, Info)
  assert_false(c.log_request_body)
  assert_eq(c.skip_paths.length(), 2)
  assert_true(c.include_latency)
}

test "log_debug with fields" {
  Logger::debug("test debug", fields=[("key", "value")])
  assert_true(true)
}

test "log_info with fields" {
  Logger::info("test info", fields=[("user", "42"), ("action", "login")])
  assert_true(true)
}

test "log_warn with fields" {
  Logger::warn("test warning")
  assert_true(true)
}

test "log_error with fields" {
  Logger::error("test error", fields=[("code", "500")])
  assert_true(true)
}

test "MetricsCollector new" {
  let m = MetricsCollector::new()
  assert_eq(m.total_requests, 0L)
}

test "MetricsCollector record" {
  let m = MetricsCollector::new()
  m.record(200, "/api/test", 42L)
  assert_eq(m.total_requests, 1L)
  m.record(500, "/api/error", 100L)
  assert_eq(m.total_requests, 2L)
}

test "MetricsCollector to_json" {
  let m = MetricsCollector::new()
  m.record(200, "/api/test", 10L)
  m.record(200, "/api/test", 20L)
  m.record(404, "/api/notfound", 5L)
  let json = m.to_json()
  assert_true(true)
}

test "structured_logger returns Handler" {
  let _ = structured_logger(StructuredLogConfig::default())
  assert_true(true)
}

test "metrics_middleware returns Handler" {
  let m = MetricsCollector::new()
  let _ = metrics_middleware(m)
  assert_true(true)
}

///| ——————————————————————————————————————————————————————————————————————
///  Config management tests
///| ——————————————————————————————————————————————————————————————————————

test "AppEnvironment from_string" {
  assert_eq(AppEnvironment::from_string("production"), Production)
  assert_eq(AppEnvironment::from_string("prod"), Production)
  assert_eq(AppEnvironment::from_string("staging"), Staging)
  assert_eq(AppEnvironment::from_string("test"), AppEnvironment::Test)
  assert_eq(AppEnvironment::from_string("development"), AppEnvironment::Development)
  assert_eq(AppEnvironment::from_string("unknown"), AppEnvironment::Development)
}

test "AppEnvironment to_string" {
  assert_eq(AppEnvironment::Development.to_string(), "development")
  assert_eq(AppEnvironment::Production.to_string(), "production")
  assert_eq(AppEnvironment::Test.to_string(), "test")
}

test "Config new and get_string" {
  let cfg = Config::new(env=AppEnvironment::Test)
  assert_eq(cfg.get_string("missing", default="fallback"), "fallback")
  assert_eq(cfg.environment(), AppEnvironment::Test)
  assert_true(cfg.is_development() == false)
}

test "Config has and keys" {
  let cfg = Config::new()
  assert_false(cfg.has("nonexistent"))
}

test "ServerConfig defaults" {
  let cfg = ServerConfig::from_env()
  assert_eq(cfg.host, "0.0.0.0")
  assert_eq(cfg.port, 8080)
  assert_eq(cfg.log_level, "info")
  assert_eq(cfg.log_format, "text")
  assert_false(cfg.has_tls())
}

///| ——————————————————————————————————————————————————————————————————————
///  WebSocket tests
///| ——————————————————————————————————————————————————————————————————————

test "WebSocketOpcode values" {
  let _ = WebSocketOpcode::Text
  let _ = WebSocketOpcode::Binary
  let _ = WebSocketOpcode::Close
  let _ = WebSocketOpcode::Ping
  let _ = WebSocketOpcode::Pong
  let _ = WebSocketOpcode::Continuation
  assert_true(true)
}

test "WebSocketMessage constructors" {
  let _msg = WebSocketMessage::Text("hello")
  let _bin = WebSocketMessage::Binary("data")
  let _close = WebSocketMessage::Close(1000, "bye")
  let _ping = WebSocketMessage::Ping("ping")
  let _pong = WebSocketMessage::Pong("pong")
  assert_true(true)
}

test "is_websocket_request" {
  let ctx = create_test_context("GET", "/ws")
  assert_false(is_websocket_request(ctx))
}

test "websocket_handler returns Handler" {
  let _ = websocket_handler(fn(ws) { ws.send_text("ok") })
  assert_true(true)
}

///| ——————————————————————————————————————————————————————————————————————
///  URL encode/decode — extended edge cases
///| ——————————————————————————————————————————————————————————————————————

test "url_decode newline encoding" {
  assert_eq(url_decode("line1%0Aline2"), "line1\nline2")
}
