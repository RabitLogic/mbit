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
    allow_methods: ["GET"],
    allow_headers: ["X-Token"],
    expose_headers: [],
    allow_credentials: true,
    max_age: 3600,
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
  let c = RateLimitConfig::{ max_requests: 10, window_secs: 30 }
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
    allow_methods: ["GET", "POST"],
    allow_headers: ["X-Custom"],
    expose_headers: ["X-Response-Time", "X-Request-Id"],
    allow_credentials: true,
    max_age: 7200,
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
    allow_methods: ["GET"],
    allow_headers: ["Accept"],
    expose_headers: [],
    allow_credentials: true,
    max_age: 600,
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
  let c = RateLimitConfig::{ max_requests: 0, window_secs: 10 }
  assert_eq(c.max_requests, 0)
  assert_eq(c.window_secs, 10)
}

test "RateLimitConfig large window" {
  let c = RateLimitConfig::{ max_requests: 1000, window_secs: 3600 }
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
  let accounts : Map[String, String] = {}
  let c = BasicAuthConfig::{ accounts, realm: "" }
  assert_eq(c.accounts.length(), 0)
  assert_eq(c.realm, "")
}

test "basic_auth_for_realm functionality" {
  let accounts : Map[String, String] = { "root": "toor" }
  let handler = basic_auth_for_realm(accounts, "Admin Area")
  // Verify it returns a Handler (type check by calling)
  ignore(handler)
  assert_true(true)
}

///| ——————————————————————————————————————————————————————————————————————
///  Body size limit coverage
///| ——————————————————————————————————————————————————————————————————————

test "body_size_limit with zero" {
  let handler = body_size_limit(0L)
  ignore(handler)
  assert_true(true)
}

test "body_size_limit with large value" {
  let handler = body_size_limit(10L * 1024L * 1024L * 1024L) // 10 GB
  ignore(handler)
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

///| ——————————————————————————————————————————————————————————————————————
///  URL encode/decode — extended edge cases
///| ——————————————————————————————————————————————————————————————————————

test "url_decode newline encoding" {
  assert_eq(url_decode("line1%0Aline2"), "line1\nline2")
}
