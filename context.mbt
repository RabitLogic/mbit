///|
/// Context — the central abstraction of mbit, inspired by Go's net/http context pattern.
///
/// Context carries the request, response writer, parsed parameters,
/// and the middleware/handler chain through a single request lifecycle.
///
/// ## Middleware chain (`ctx.next()`)
///
/// Each request runs through a chain of handlers. Middleware calls `c.next()`
/// to yield to the next handler in the chain:
///
/// ```
/// // Logging middleware
/// fn logger(ctx) {
///   let start = now()
///   ctx.next()    // <-- runs the rest of the chain
///   let elapsed = now() - start
///   println("\{ctx.method()} \{ctx.path()} -> \{ctx.status_code} (\{elapsed}ms)")
/// }
/// ```

///|
/// Handler function signature.
/// All route handlers and middleware share this signature.
pub type Handler = async (Context) -> Unit

///| ——————————————————————————————————————————————————————————————————————
///  Response connection abstraction
///| ——————————————————————————————————————————————————————————————————————

///|
/// In-memory connection used by tests — captures status, headers, and body.
pub(all) struct TestConn {
  mut status : Int
  mut reason : String
  headers : Map[String, String]
  mut body : String
  mut header_sent : Bool
  mut ended : Bool
}

///|
/// Create a fresh in-memory test connection.
pub fn TestConn::new() -> TestConn {
  {
    status: 0,
    reason: "",
    headers: {},
    body: "",
    header_sent: false,
    ended: false,
  }
}

///|
/// The response sink — either a real HTTP server connection or an
/// in-memory buffer used for testing.
pub(all) enum ResponseConn {
  Real(@http.ServerConnection)
  Test(TestConn)
}

///|
/// Send the response status line and headers.
pub async fn ResponseConn::send_response(
  self : ResponseConn,
  code : Int,
  reason : String,
  extra_headers~ : Map[String, String] = {},
) -> Unit {
  match self {
    Real(c) => c.send_response(code, reason, extra_headers~)
    Test(t) => {
      t.status = code
      t.reason = reason
      for k, v in extra_headers {
        t.headers.set(k, v)
      }
      t.header_sent = true
    }
  }
}

///|
/// Write a chunk of the response body.
pub async fn ResponseConn::write_body(self : ResponseConn, s : String) -> Unit {
  match self {
    Real(c) => c.write_string(s)
    Test(t) => t.body = t.body + s
  }
}

///|
/// Finish the response.
pub async fn ResponseConn::end_response(self : ResponseConn) -> Unit {
  match self {
    Real(c) => c.end_response()
    Test(t) => t.ended = true
  }
}

///|
/// Flush buffered data to the client.
pub async fn ResponseConn::flush(self : ResponseConn) -> Unit {
  match self {
    Real(c) => c.flush()
    Test(_) => ()
  }
}

///|
/// Context holds all per-request state.
pub(all) struct Context {
  // === Raw HTTP ===
  /// The incoming HTTP request (method, path, headers, etc.)
  req : @http.Request
  /// Reader for reading the request body
  reader : &@io.Reader
  /// Response sink for sending the response
  conn : ResponseConn

  // === Parsed state ===
  /// Path parameters extracted from the route pattern (e.g., `:id`)
  mut params : Map[String, String]
  /// Query parameters — parsed lazily on first access
  mut query_cache : Map[String, String]?
  /// Full request body — read lazily on first access
  mut body : String?
  /// Post form data — parsed lazily on first access
  mut post_form_cache : Map[String, String]?

  // === Middleware chain ===
  /// All handlers (middleware + route handler) for this request
  mut handlers : Array[Handler]
  /// Current position in the handler chain
  mut index : Int

  // === Response ===
  /// HTTP status code to send (default 200)
  mut status_code : Int
  /// Whether the response has already been written
  mut written : Bool
  /// Whether the handler chain has been aborted
  mut aborted : Bool
  /// Number of bytes written to the response
  mut size : Int

  // === Key-value store ===
  /// Arbitrary data shared between middleware and handlers
  mut store : Map[String, Json]

  // === Errors ===
  /// Errors collected during request processing
  mut errors : Array[String]

  // === Response headers ===
  /// Extra headers to include in the response
  mut headers : Map[String, String]
}

///|
/// Create a new Context from the raw HTTP components and handler chain.
pub fn Context::new(
  req : @http.Request,
  reader : &@io.Reader,
  conn : ResponseConn,
  handlers : Array[Handler],
) -> Context {
  {
    req,
    reader,
    conn,
    params: {},
    query_cache: None,
    body: None,
    post_form_cache: None,
    handlers,
    index: 0,
    status_code: 200,
    written: false,
    aborted: false,
    size: 0,
    store: {},
    errors: [],
    headers: {},
  }
}

///| ——————————————————————————————————————————————————————————————————————
///  Request accessors
///| ——————————————————————————————————————————————————————————————————————

///|
/// The HTTP method of the request (e.g., "GET", "POST").
pub fn Context::method(self : Context) -> String {
  Method::from_native(self.req.meth).to_string()
}

///|
/// Request returns the raw HTTP request.
/// See `c.Request` equivalent.
pub fn Context::request(self : Context) -> @http.Request {
  self.req
}

///|
/// The full request path including query string.
pub fn Context::full_path(self : Context) -> String {
  self.req.path
}

///|
/// The request path without the query string.
pub fn Context::path(self : Context) -> String {
  match self.req.path.find("?") {
    Some(pos) => self.req.path[:pos].to_owned()
    None => self.req.path
  }
}

///|
/// A request header value, if present.
pub fn Context::header(self : Context, key : String) -> String? {
  self.req.headers.get(key)
}

///|
/// GetHeader is an alias for `header()` — for API compatibility.
/// See `c.GetHeader()` equivalent.
pub fn Context::get_header(self : Context, key : String) -> String? {
  self.header(key)
}

///|
/// The client's IP address.
pub fn Context::client_ip(self : Context) -> String {
  // Check X-Forwarded-For first (common proxy header)
  match self.req.headers.get("x-forwarded-for") {
    Some(ip) =>
      // Take the first IP if there are multiple
      match ip.find(",") {
        Some(pos) => ip[:pos].trim().to_owned()
        None => ip
      }
    None =>
      match self.req.headers.get("x-real-ip") {
        Some(ip) => ip
        None => "127.0.0.1"
      }
  }
}

///|
/// Returns the value of the `Content-Type` request header.
pub fn Context::content_type(self : Context) -> String {
  match self.header("Content-Type") {
    Some(ct) => ct
    None => ""
  }
}

///|
/// Check if the request is a WebSocket upgrade request.
pub fn Context::is_websocket(self : Context) -> Bool {
  match self.header("Connection") {
    Some(conn) =>
      conn.to_lower() == "upgrade" &&
      (match self.header("Upgrade") {
        Some(up) => up.to_lower() == "websocket"
        None => false
      })
    None => false
  }
}

///| ——————————————————————————————————————————————————————————————————————
///  Cookie helpers
///| ——————————————————————————————————————————————————————————————————————

///|
/// Get a cookie value by name from the request headers.
///
/// ```
/// let session = ctx.cookie("session_id")
/// ```
pub fn Context::cookie(self : Context, name : String) -> String? {
  let cookie_header = match self.header("Cookie") {
    Some(c) => c
    None => return None
  }
  // Parse "name1=value1; name2=value2"
  let parts = cookie_header.split(";")
  for part in parts {
    let trimmed = part.trim()
    match trimmed.find("=") {
      Some(pos) => {
        let key = trimmed[:pos].trim().to_owned()
        if key == name {
          return Some(trimmed[pos + 1:].trim().to_owned())
        }
      }
      None => ()
    }
  }
  None
}

///|
/// Set a cookie in the response headers.
///
/// ```
/// ctx.set_cookie("session_id", "abc123", max_age=3600, path="/", http_only=true)
/// ```
pub fn Context::set_cookie(
  self : Context,
  name : String,
  value : String,
  max_age~ : Int = 0,
  path~ : String = "/",
  domain~ : String = "",
  secure~ : Bool = false,
  http_only~ : Bool = false,
  same_site~ : String = "",
) -> Unit {
  let mut cookie = name + "=" + value
  if path != "" {
    cookie = cookie + "; Path=" + path
  }
  if domain != "" {
    cookie = cookie + "; Domain=" + domain
  }
  if max_age > 0 {
    cookie = cookie + "; Max-Age=" + max_age.to_string()
  }
  if secure {
    cookie = cookie + "; Secure"
  }
  if http_only {
    cookie = cookie + "; HttpOnly"
  }
  if same_site != "" {
    cookie = cookie + "; SameSite=" + same_site
  }
  self.set_header("Set-Cookie", cookie)
}

///| ——————————————————————————————————————————————————————————————————————
///  Path parameters
///| ——————————————————————————————————————————————————————————————————————

///|
/// Get a path parameter by name.
/// Route patterns like `/api/article/:id` populate `ctx.param("id")`.
pub fn Context::param(self : Context, key : String) -> String? {
  self.params.get(key)
}

///|
/// Get a path parameter, returning a default value if not present.
pub fn Context::param_default(
  self : Context,
  key : String,
  default : String,
) -> String {
  match self.params.get(key) {
    Some(v) => v
    None => default
  }
}

///|
/// Get a path parameter parsed as Int64.
pub fn Context::param_int64(self : Context, key : String) -> Int64? {
  match self.params.get(key) {
    Some(v) =>
      match (try? @string.parse_int64(v)) {
        Ok(n) => Some(n)
        Err(_) => None
      }
    None => None
  }
}

///|
/// All parsed path parameters.
pub fn Context::params_all(self : Context) -> Map[String, String] {
  self.params
}

///| ——————————————————————————————————————————————————————————————————————
///  Query parameters (lazy)
///| ——————————————————————————————————————————————————————————————————————

///|
/// Parse query string on first access and cache for subsequent calls.
fn Context::parse_query(self : Context) -> Unit {
  match self.query_cache {
    Some(_) => ()
    None => {
      let qs = match self.req.path.find("?") {
        Some(pos) => self.req.path[pos + 1:].to_owned()
        None => ""
      }
      let map : Map[String, String] = {}
      if qs != "" {
        let pairs = qs.split("&")
        for pair in pairs {
          match pair.find("=") {
            Some(i) => {
              let k = url_decode(pair[:i].to_owned())
              let v = url_decode(pair[i + 1:].to_owned())
              map.set(k, v)
            }
            None => ()
          }
        }
      }
      self.query_cache = Some(map)
    }
  }
}

///|
/// Get a query parameter by name.
pub fn Context::query(self : Context, key : String) -> String? {
  self.parse_query()
  match self.query_cache {
    Some(map) => map.get(key)
    None => None
  }
}

///|
/// Get a query parameter with a default fallback.
pub fn Context::query_default(
  self : Context,
  key : String,
  default : String,
) -> String {
  match self.query(key) {
    Some(v) => v
    None => default
  }
}

///|
/// Get a query parameter parsed as Int64.
pub fn Context::query_int64(self : Context, key : String) -> Int64? {
  match self.query(key) {
    Some(v) =>
      match (try? @string.parse_int64(v)) {
        Ok(n) => Some(n)
        Err(_) => None
      }
    None => None
  }
}

///|
/// Get a query parameter parsed as Int.
pub fn Context::query_int(self : Context, key : String) -> Int? {
  match self.query(key) {
    Some(v) =>
      match (try? @string.parse_int(v)) {
        Ok(n) => Some(n)
        Err(_) => None
      }
    None => None
  }
}

///| ——————————————————————————————————————————————————————————————————————
///  Post form parameters (application/x-www-form-urlencoded body)
///| ——————————————————————————————————————————————————————————————————————

///|
/// Get a value from the POST form body.
/// Parses the body as application/x-www-form-urlencoded on first access.
pub async fn Context::post_form(self : Context, key : String) -> String? {
  self.parse_post_form()
  match self.post_form_cache {
    Some(map) => map.get(key)
    None => None
  }
}

///|
/// Get a post form value with a default fallback.
pub async fn Context::default_post_form(
  self : Context,
  key : String,
  default : String,
) -> String {
  match self.post_form(key) {
    Some(v) => v
    None => default
  }
}

///|
/// Parse the request body as URL-encoded form data (lazy, cached).
async fn Context::parse_post_form(self : Context) -> Unit {
  match self.post_form_cache {
    Some(_) => ()
    None => {
      let raw = self.body_string()
      let map : Map[String, String] = {}
      if raw != "" {
        let pairs = raw.split("&")
        for pair in pairs {
          match pair.find("=") {
            Some(i) => {
              let k = url_decode(pair[:i].to_owned())
              let v = url_decode(pair[i + 1:].to_owned())
              map.set(k, v)
            }
            None => map.set(url_decode(pair.to_owned()), "")
          }
        }
      }
      self.post_form_cache = Some(map)
    }
  }
}

///| ——————————————————————————————————————————————————————————————————————
///  Middleware chain (middleware chain pattern)
///| ——————————————————————————————————————————————————————————————————————

///|
/// Next should be called only inside middleware.
/// It executes the remaining handlers in the chain.
///
/// This is the heart of the middleware chain pattern:
/// - Middleware runs code BEFORE `c.next()`
/// - `c.next()` yields to the next handler and waits for it
/// - Middleware runs code AFTER `c.next()` returns
pub async fn Context::next(self : Context) -> Unit {
  self.index = self.index + 1
  if self.index < self.handlers.length() && !self.aborted {
    let h = self.handlers[self.index]
    h(self)
  }
}

///|
/// Abort the handler chain. No further handlers will be executed.
/// Does NOT write a response — you should call a render method separately.
pub fn Context::abort(self : Context) -> Unit {
  self.aborted = true
}

///|
/// Abort with a specific status code and JSON error message.
pub async fn Context::abort_with_status(
  self : Context,
  code : Int,
  message : String,
) -> Unit {
  self.aborted = true
  let body : Json = Json::object({
    "error": Json::string(message),
    "code": Json::number(code.to_double()),
  })
  self.json(code, body)
}

///|
/// Whether the chain has been aborted.
pub fn Context::is_aborted(self : Context) -> Bool {
  self.aborted
}

///| ——————————————————————————————————————————————————————————————————————
///  Key-value store (for middleware data sharing)
///| ——————————————————————————————————————————————————————————————————————

///|
/// Store a value in the context. Useful for middleware to pass data to handlers.
/// Example: auth middleware stores `ctx.set("user_id", json)`.
pub fn Context::set(self : Context, key : String, value : Json) -> Unit {
  self.store.set(key, value)
}

///|
/// Retrieve a value from the context store.
pub fn Context::get(self : Context, key : String) -> Json? {
  self.store.get(key)
}

///|
/// Retrieve a string value from the context store.
pub fn Context::get_string(self : Context, key : String) -> String? {
  match self.store.get(key) {
    Some(Json::String(s)) => Some(s)
    _ => None
  }
}

///|
/// Retrieve an Int64 value from the context store.
pub fn Context::get_int64(self : Context, key : String) -> Int64? {
  match self.store.get(key) {
    Some(Json::Number(n, ..)) => Some(n.to_int64())
    _ => None
  }
}

///|
/// GetTime retrieves a time value (stored as Int64 nanoseconds) from the store.
/// See `c.GetTime()` equivalent.
pub fn Context::get_time(self : Context, key : String) -> Int64? {
  self.get_int64(key)
}

///|
/// GetDuration retrieves a duration value (stored as Int64 nanoseconds) from the store.
/// See `c.GetDuration()` equivalent.
pub fn Context::get_duration(self : Context, key : String) -> Int64? {
  self.get_int64(key)
}

///|
/// GetStringMap returns a string map from the store.
/// See `c.GetStringMap()` equivalent.
pub fn Context::get_string_map(
  self : Context,
  key : String,
) -> Map[String, String]? {
  match self.store.get(key) {
    Some(Json::Object(map)) => {
      let result : Map[String, String] = {}
      for k, v in map {
        match v {
          Json::String(s) => result.set(k, s)
          _ => ()
        }
      }
      Some(result)
    }
    _ => None
  }
}

///|
/// GetStringMapString returns a flat string map from the store.
/// See `c.GetStringMapString()` equivalent.
pub fn Context::get_string_map_string(
  self : Context,
  key : String,
) -> Map[String, String]? {
  self.get_string_map(key)
}

///|
/// Retrieve a Bool value from the context store.
pub fn Context::get_bool(self : Context, key : String) -> Bool? {
  match self.store.get(key) {
    Some(Json::True) => Some(true)
    Some(Json::False) => Some(false)
    _ => None
  }
}

///|
/// Retrieve a Float64 value from the context store.
pub fn Context::get_float64(self : Context, key : String) -> Double? {
  match self.store.get(key) {
    Some(Json::Number(n, ..)) => Some(n)
    _ => None
  }
}

///|
/// MustGet returns the value for the given key if it exists, otherwise panics.
/// Use this when the value is guaranteed to have been set by middleware.
pub fn Context::must_get(self : Context, key : String) -> Json {
  match self.store.get(key) {
    Some(v) => v
    None => abort("Key \{key} does not exist in context store")
  }
}

///| ——————————————————————————————————————————————————————————————————————
///  Response rendering
///| ——————————————————————————————————————————————————————————————————————

///|
/// Set the HTTP status code for the response.
pub fn Context::status(self : Context, code : Int) -> Unit {
  self.status_code = code
}

///|
/// Set a response header.
pub fn Context::set_header(self : Context, key : String, value : String) -> Unit {
  self.headers.set(key, value)
}

///|
/// SetAccepted sets the accepted content types for content negotiation.
/// See `c.SetAccepted()` equivalent.
pub fn Context::set_accepted(self : Context, formats : Array[String]) -> Unit {
  self.set_header("Accept", formats[0])
}

///|
/// Content negotiation: returns the best accepted content type from the
/// `Accept` header. If none matches, sets a 406 status and returns `None`.
///
/// ```
/// match ctx.negotiate_format(["application/json", "text/html"]) {
///   Some("application/json") => ctx.json(200, data)
///   Some("text/html") => ctx.html(200, "<h1>Hello</h1>")
///   _ => ()  // 406 already set
/// }
/// ```
pub async fn Context::negotiate_format(
  self : Context,
  offered : Array[String],
) -> String? {
  let accept = match self.header("Accept") {
    Some(a) => a
    None => {
      // No Accept header — return the first offered type
      if offered.length() > 0 {
        return Some(offered[0])
      }
      return None
    }
  }
  // Parse Accept header: "text/html, application/json;q=0.9, */*;q=0.8"
  // Simple implementation: exact match
  for offer in offered {
    if accept.find(offer).is_some() {
      return Some(offer)
    }
  }
  // Check for wildcard
  if accept.find("*/*").is_some() && offered.length() > 0 {
    return Some(offered[0])
  }
  // No match — 406 Not Acceptable
  self.abort_with_status(406, "Not Acceptable")
  None
}

///|
/// Render JSON. This finalizes the response; no further writes are allowed.
pub async fn Context::json(self : Context, code : Int, data : Json) -> Unit {
  if self.written {
    return
  }
  self.written = true
  self.status_code = code
  let all_headers = self.headers
  all_headers.set("Content-Type", "application/json")
  self.conn.send_response(code, status_text(code), extra_headers=all_headers)
  self.conn.write_body(data.stringify())
  self.conn.end_response()
}

///|
/// Render a plain text string.
pub async fn Context::string(self : Context, code : Int, s : String) -> Unit {
  if self.written {
    return
  }
  self.written = true
  self.status_code = code
  let all_headers = self.headers
  all_headers.set("Content-Type", "text/plain; charset=utf-8")
  self.conn.send_response(code, status_text(code), extra_headers=all_headers)
  self.conn.write_body(s)
  self.conn.end_response()
}

///|
/// StringF renders a formatted string response (printf-style).
/// Supports simple {0}, {1} placeholders for variable substitution.
///
/// ```
/// ctx.string_f(200, "Hello {0}, you are {1} years old", ["Alice", "30"])
/// ```
pub async fn Context::string_f(
  self : Context,
  code : Int,
  template : String,
  args : Array[String],
) -> Unit {
  let mut result = template
  for i = 0; i < args.length(); i = i + 1 {
    let placeholder = "{" + i.to_string() + "}"
    result = result.replace_all(old=placeholder, new=args[i])
  }
  self.string(code, result)
}

///|
/// Render HTML.
pub async fn Context::html(self : Context, code : Int, html : String) -> Unit {
  if self.written {
    return
  }
  self.written = true
  self.status_code = code
  let all_headers = self.headers
  all_headers.set("Content-Type", "text/html; charset=utf-8")
  self.conn.send_response(code, status_text(code), extra_headers=all_headers)
  self.conn.write_body(html)
  self.conn.end_response()
}

///|
/// Send a response with custom content type.
pub async fn Context::data(
  self : Context,
  code : Int,
  content_type : String,
  body : String,
) -> Unit {
  if self.written {
    return
  }
  self.written = true
  self.status_code = code
  let all_headers = self.headers
  all_headers.set("Content-Type", content_type)
  self.conn.send_response(code, status_text(code), extra_headers=all_headers)
  self.conn.write_body(body)
  self.conn.end_response()
}

///|
/// Redirect to another URL.
pub async fn Context::redirect(
  self : Context,
  code : Int,
  location : String,
) -> Unit {
  if self.written {
    return
  }
  self.written = true
  self.status_code = code
  let all_headers = self.headers
  all_headers.set("Location", location)
  self.conn.send_response(code, status_text(code), extra_headers=all_headers)
  self.conn.end_response()
}

///|
/// Render XML. Converts a JSON object to XML format.
/// The JSON keys become XML tag names, values become text content.
///
/// ```
/// ctx.xml(200, Json::object(H([
///   ("user", Json::object(H([
///     ("name", Json::string("Alice")),
///     ("age", Json::string("30")),
///   ]))),
/// ])))
/// // Output: <root><user><name>Alice</name><age>30</age></user></root>
/// ```
pub async fn Context::xml(
  self : Context,
  code : Int,
  data : Json,
  root_tag~ : String = "root",
) -> Unit {
  if self.written {
    return
  }
  self.written = true
  self.status_code = code
  let all_headers = self.headers
  all_headers.set("Content-Type", "application/xml; charset=utf-8")
  self.conn.send_response(code, status_text(code), extra_headers=all_headers)
  let xml = json_to_xml(root_tag, data)
  self.conn.write_body(xml)
  self.conn.end_response()
}

///|
/// Render YAML. Converts a JSON object to YAML format.
///
/// ```
/// ctx.yaml(200, Json::object(H([
///   ("name", Json::string("Alice")),
///   ("age", Json::string("30")),
/// ])))
/// // Output:
/// // name: Alice
/// // age: "30"
/// ```
pub async fn Context::yaml(
  self : Context,
  code : Int,
  data : Json,
) -> Unit {
  if self.written {
    return
  }
  self.written = true
  self.status_code = code
  let all_headers = self.headers
  all_headers.set("Content-Type", "application/x-yaml; charset=utf-8")
  self.conn.send_response(code, status_text(code), extra_headers=all_headers)
  let yaml = json_to_yaml(data, indent=0)
  self.conn.write_body(yaml)
  self.conn.end_response()
}

///|
/// Render indented / pretty-printed JSON.
/// Same as `json()` but with indentation for readability.
pub async fn Context::indented_json(
  self : Context,
  code : Int,
  data : Json,
) -> Unit {
  if self.written {
    return
  }
  self.written = true
  self.status_code = code
  let all_headers = self.headers
  all_headers.set("Content-Type", "application/json")
  self.conn.send_response(code, status_text(code), extra_headers=all_headers)
  // Try to produce indented JSON if the parser supports it
  let raw = data.stringify()
  let indented = pretty_json(raw)
  self.conn.write_body(indented)
  self.conn.end_response()
}

///|
/// Render SecureJSON — prepends `while(1);` to prevent JSON hijacking.
/// See `c.SecureJSON()` equivalent.
pub async fn Context::secure_json(
  self : Context,
  code : Int,
  data : Json,
) -> Unit {
  if self.written {
    return
  }
  self.written = true
  self.status_code = code
  let all_headers = self.headers
  all_headers.set("Content-Type", "application/json")
  self.conn.send_response(code, status_text(code), extra_headers=all_headers)
  self.conn.write_body("while(1);" + data.stringify())
  self.conn.end_response()
}

///|
/// Render PureJSON — writes JSON without escaping HTML characters.
/// (In MoonBit, the default JSON stringify does not escape HTML, so this is
/// equivalent to `json()` — included for API completeness.)
pub async fn Context::pure_json(self : Context, code : Int, data : Json) -> Unit {
  self.json(code, data)
}

///|
/// Render JSONP — wraps JSON in a callback function.
/// The callback name is taken from the `callback` query parameter.
///
/// See `c.JSONP()` equivalent.
pub async fn Context::jsonp(self : Context, code : Int, data : Json) -> Unit {
  if self.written {
    return
  }
  self.written = true
  self.status_code = code
  let callback = self.query_default("callback", "callback")
  let all_headers = self.headers
  all_headers.set("Content-Type", "application/javascript")
  self.conn.send_response(code, status_text(code), extra_headers=all_headers)
  self.conn.write_body(callback + "(" + data.stringify() + ")")
  self.conn.end_response()
}

///|
/// Send a file as an attachment (forces download with Content-Disposition).
///
/// See `c.FileAttachment()` equivalent.
pub async fn Context::file_attachment(
  self : Context,
  file_path : String,
  filename~ : String = "",
) -> Unit {
  if self.written {
    return
  }
  self.written = true
  self.status_code = 200
  let name = if filename == "" {
    // Extract filename from path
    match file_path.rev_find("/") {
      Some(pos) => file_path[pos + 1:].to_owned()
      None => file_path
    }
  } else {
    filename
  }
  let ct = guess_content_type(file_path)
  let all_headers = self.headers
  all_headers.set("Content-Type", ct)
  all_headers.set(
    "Content-Disposition",
    "attachment; filename=\"" + name + "\"",
  )
  self.conn.send_response(200, "OK", extra_headers=all_headers)
  try {
    let content = @fs.read_file(file_path).text()
    self.conn.write_body(content)
  } catch {
    _ => ()
  }
  self.conn.end_response()
}

///|
/// HandlerName returns the name of the last handler in the chain.
/// Useful for debugging and logging.
pub fn Context::handler_name(self : Context) -> String {
  if self.handlers.length() > 0 {
    let last_idx = self.handlers.length() - 1
    // Return a simple identifier — in MoonBit we use index as name
    "handler_" + last_idx.to_string()
  } else {
    "unknown"
  }
}

///|
/// HandlerNames returns the names of all handlers in the chain.
pub fn Context::handler_names(self : Context) -> Array[String] {
  let names : Array[String] = []
  for i = 0; i < self.handlers.length(); i = i + 1 {
    names.push("handler_" + i.to_string())
  }
  names
}

///|
/// Simple JSON pretty-printing — adds indentation and newlines.
fn pretty_json(raw : String) -> String {
  let mut result = ""
  let mut indent = 0
  let mut i = 0
  let chars = raw.to_array()
  while i < chars.length() {
    let ch = chars[i]
    match ch {
      '{' | '[' => {
        result = result + ch.to_string() + "\n"
        indent = indent + 2
        result = result + " ".repeat(indent)
      }
      '}' | ']' => {
        indent = indent - 2
        if indent < 0 {
          indent = 0
        }
        result = result + "\n" + " ".repeat(indent) + ch.to_string()
      }
      ',' => result = result + ",\n" + " ".repeat(indent)
      ':' => result = result + ": "
      _ => result = result + ch.to_string()
    }
    i = i + 1
  }
  result
}

///|
/// Send a 204 No Content response.
pub async fn Context::no_content(self : Context) -> Unit {
  if self.written {
    return
  }
  self.written = true
  self.status_code = 204
  let all_headers = self.headers
  self.conn.send_response(204, "No Content", extra_headers=all_headers)
  self.conn.end_response()
}

///|
/// FileFromFS serves a file from a filesystem path.
/// See `c.FileFromFS()` equivalent.
pub async fn Context::file_from_fs(self : Context, file_path : String) -> Unit {
  self.file(200, guess_content_type(file_path), file_path)
}

///|
/// Send a file as the response body with the given content type.
/// The file content is read from disk and sent inline.
///
/// ```
/// ctx.file(200, "application/pdf", "./reports/annual.pdf")
/// ```
pub async fn Context::file(
  self : Context,
  code : Int,
  content_type : String,
  file_path : String,
) -> Unit {
  if self.written {
    return
  }
  self.written = true
  self.status_code = code
  let all_headers = self.headers
  all_headers.set("Content-Type", content_type)
  self.conn.send_response(code, status_text(code), extra_headers=all_headers)
  // Read and stream file content
  try {
    let content = @fs.read_file(file_path).text()
    self.conn.write_body(content)
  } catch {
    _ => ()
  }
  self.conn.end_response()
}

///|
/// Stream a Server-Sent Event (SSE) to the client.
/// Sets the appropriate headers for SSE.
///
/// ```
/// // Basic SSE
/// ctx.sse("message", "hello world")
/// ```
pub async fn Context::sse(self : Context, event : String, data : String) -> Unit {
  self.sse_ex(event, data~, id="", retry=0)
}

///|
/// Backward-compatible alias for `sse()`.
pub async fn Context::stream_sse(
  self : Context,
  event : String,
  data : String,
) -> Unit {
  self.sse(event, data)
}

///|
/// SSE with full options: id, retry, comment.
pub async fn Context::sse_ex(
  self : Context,
  event : String,
  data~ : String,
  id~ : String = "",
  retry~ : Int = 0,
  comment~ : String = "",
) -> Unit {
  let mut payload = ""

  // Comment (for keep-alive pings or debugging)
  if comment != "" {
    let lines = comment.split("\n")
    for line in lines {
      payload = payload + ": " + line.to_owned() + "\n"
    }
  }

  // Event ID — allows client to resume from last received event
  if id != "" {
    payload = payload + "id: " + id + "\n"
  }

  // Retry — reconnection time in milliseconds
  if retry > 0 {
    payload = payload + "retry: " + retry.to_string() + "\n"
  }

  // Event type
  if event != "" {
    payload = payload + "event: " + event + "\n"
  }

  // Data (supports multi-line: each line becomes "data: ...")
  let data_lines = data.split("\n")
  for line in data_lines {
    payload = payload + "data: " + line.to_owned() + "\n"
  }

  // Double newline terminates the event
  payload = payload + "\n"
  if self.written {
    // After initial SSE headers, subsequent writes are fine
    self.conn.write_body(payload)
    return
  }
  self.written = true
  self.status_code = 200
  let all_headers = self.headers
  all_headers.set("Content-Type", "text/event-stream")
  all_headers.set("Cache-Control", "no-cache")
  all_headers.set("Connection", "keep-alive")
  all_headers.set("X-Accel-Buffering", "no") // Disable nginx buffering
  self.conn.send_response(200, "OK", extra_headers=all_headers)
  self.conn.write_body(payload)
}

///|
/// SSE keep-alive — sends a comment-only event to prevent connection timeout.
/// Useful for long-lived SSE connections.
///
/// ```
/// ctx.sse_keepalive("ping")
/// ```
pub async fn Context::sse_keepalive(self : Context, comment : String) -> Unit {
  self.sse_ex("", data="", comment~)
}

///|
/// Flush the SSE response — sends buffered data to the client immediately.
pub async fn Context::sse_flush(self : Context) -> Unit {
  self.conn.flush()
}

///| ——————————————————————————————————————————————————————————————————————
///  Streaming responses
///| ——————————————————————————————————————————————————————————————————————

///|
/// Stream writes a streaming response with the given status code and
/// content type. The `writer` callback receives a function that writes
/// chunks to the connection.
///
/// ```
/// ctx.stream(200, "text/event-stream", fn(write) {
///   for i = 0; i < 10; i = i + 1 {
///     write("data: chunk " + i.to_string() + "\n\n")
///   }
/// })
/// ```
pub async fn Context::stream(
  self : Context,
  code : Int,
  content_type : String,
  writer : async (async (String) -> Unit) -> Unit,
) -> Unit {
  if self.written {
    return
  }
  self.written = true
  self.status_code = code
  let all_headers = self.headers
  all_headers.set("Content-Type", content_type)
  all_headers.set("Transfer-Encoding", "chunked")
  all_headers.set("X-Content-Type-Options", "nosniff")
  self.conn.send_response(code, status_text(code), extra_headers=all_headers)

  // The writer callback sends chunks
  writer(fn(chunk : String) {
    self.conn.write_body(chunk)
    self.size = self.size + chunk.length()
  })
  self.conn.end_response()
}

///|
/// DataFromReader writes the specified content type and reads data
/// from the given reader, sending it as the response body.
///
/// ```
/// ctx.data_from_reader(200, content_length, "application/octet-stream", reader)
/// ```
pub async fn Context::data_from_reader(
  self : Context,
  code : Int,
  content_length : Int64,
  content_type : String,
  reader : &@io.Reader,
) -> Unit {
  if self.written {
    return
  }
  self.written = true
  self.status_code = code
  let all_headers = self.headers
  all_headers.set("Content-Type", content_type)
  all_headers.set("Content-Length", content_length.to_string())
  self.conn.send_response(code, status_text(code), extra_headers=all_headers)

  // Read everything from the reader and write it to the connection
  let s = (reader.read_all().text()) catch { _ => "" }
  self.conn.write_body(s)
  self.size = self.size + s.length()
  self.conn.end_response()
}

///| ——————————————————————————————————————————————————————————————————————
///  Response headers (bulk)
///| ——————————————————————————————————————————————————————————————————————

///|
/// Set multiple response headers at once.
pub fn Context::set_headers(self : Context, hdrs : Map[String, String]) -> Unit {
  for k, v in hdrs {
    self.headers.set(k, v)
  }
}

///| ——————————————————————————————————————————————————————————————————————
///  Request body
///| ——————————————————————————————————————————————————————————————————————

///|
/// Read the full request body as a string (lazy, cached).
pub async fn Context::body_string(self : Context) -> String {
  match self.body {
    Some(b) => b
    None => {
      let s = (self.reader.read_all().text()) catch { _ => "" }
      self.body = Some(s)
      s
    }
  }
}

///|
/// Parse the request body as JSON.
pub async fn Context::body_json(self : Context) -> Json? {
  let raw = self.body_string()
  match (try? @json.parse(raw)) {
    Ok(j) => Some(j)
    Err(_) => None
  }
}

///|
/// Auto-detect the content type and bind the request body to a struct.
/// Supports JSON (`application/json`) and form-encoded
/// (`application/x-www-form-urlencoded`).
///
/// Returns `Some(value)` on success, `None` on failure.
pub async fn[T : @json.FromJson] Context::should_bind(self : Context) -> T? {
  let ct = self.content_type()
  if ct.find("application/json").is_some() {
    bind_json(self)
  } else if ct.find("application/x-www-form-urlencoded").is_some() {
    bind_form(self)
  } else {
    // Default to JSON
    bind_json(self)
  }
}

///|
/// Like `should_bind` but aborts with 400 if binding fails.
pub async fn[T : @json.FromJson] Context::must_bind(self : Context) -> T {
  let bound : T? = self.should_bind()
  match bound {
    Some(v) => v
    None => {
      self.abort_with_status(400, "Invalid request body")
      abort("must_bind failed")
    }
  }
}

///|
/// ShouldBindJSON binds the JSON request body to a struct.
/// See `c.ShouldBindJSON()` equivalent.
pub async fn[T : @json.FromJson] Context::should_bind_json(
  self : Context,
) -> T? {
  bind_json(self)
}

///|
/// ShouldBindQuery binds query parameters to a struct.
/// See `c.ShouldBindQuery()` equivalent.
pub fn[T : @json.FromJson] Context::should_bind_query(self : Context) -> T? {
  bind_query(self)
}

///|
/// ShouldBindForm binds form-encoded body to a struct.
pub async fn[T : @json.FromJson] Context::should_bind_form(
  self : Context,
) -> T? {
  bind_form(self)
}

///|
/// ShouldBindHeader binds request headers to a struct.
pub fn[T : @json.FromJson] Context::should_bind_header(self : Context) -> T? {
  bind_header(self)
}

///|
/// ShouldBindUri binds URI (path) parameters to a struct.
/// See `c.ShouldBindUri()` equivalent.
pub fn[T : @json.FromJson] Context::should_bind_uri(self : Context) -> T? {
  bind_path(self)
}

///|
/// ShouldBindWith binds using a custom binding function.
/// See `c.ShouldBindWith()` equivalent.
pub async fn[T] Context::should_bind_with(
  self : Context,
  binder : async (Context) -> T?,
) -> T? {
  binder(self)
}

///|
/// MustBindWith binds using a custom binding function, aborting on failure.
/// See `c.MustBindWith()` equivalent.
pub async fn[T] Context::must_bind_with(
  self : Context,
  binder : async (Context) -> T?,
) -> T {
  match binder(self) {
    Some(v) => v
    None => {
      self.abort_with_status(400, "Binding failed")
      abort("must_bind_with failed")
    }
  }
}

///|
/// Bind auto-detects content type and binds, aborting on failure.
/// See `c.Bind()` equivalent.
pub async fn[T : @json.FromJson] Context::bind_api(self : Context) -> T? {
  self.bind_json_api()
}

///|
/// Get the raw request body as a string.
pub async fn Context::raw_data(self : Context) -> String {
  self.body_string()
}

///| ——————————————————————————————————————————————————————————————————————
///  Error collection
///| ——————————————————————————————————————————————————————————————————————

///|
/// Add an error to the context's error list.
pub fn Context::add_error(self : Context, err : String) -> Unit {
  self.errors.push(err)
}

///|
/// All collected errors.
pub fn Context::errors_all(self : Context) -> Array[String] {
  self.errors
}

///| ——————————————————————————————————————————————————————————————————————
///  Internal helpers
///| ——————————————————————————————————————————————————————————————————————

///|
/// Set parsed path parameters (called by the router after matching).
pub fn Context::set_params(
  self : Context,
  params : Map[String, String],
) -> Unit {
  self.params = params
}

///|
/// Whether the response has been written.
pub fn Context::is_written(self : Context) -> Bool {
  self.written
}

///|
/// Returns the number of bytes written to the response so far.
/// See `c.Writer.Size()` equivalent.
pub fn Context::size(self : Context) -> Int {
  self.size
}

///|
/// Flush writes any buffered data to the client.
/// See `c.Writer.Flush()` equivalent.
pub async fn Context::flush(self : Context) -> Unit {
  self.conn.flush()
}

///|
/// WriteHeaderNow forces the HTTP headers to be written.
/// See `c.Writer.WriteHeaderNow()` equivalent.
pub async fn Context::write_header_now(self : Context) -> Unit {
  if !self.written {
    self.conn.send_response(
      self.status_code,
      status_text(self.status_code),
      extra_headers=self.headers,
    )
    self.written = true
  }
}

///|
/// Written returns true if the response has been written.
/// See `c.Writer.Written()` equivalent.
pub fn Context::written(self : Context) -> Bool {
  self.written
}

///|
/// Reset the context state for reuse (used by HandleContext).
pub fn Context::reset(self : Context) -> Unit {
  self.index = 0
  self.aborted = false
  self.written = false
  self.status_code = 200
  self.errors = []
  self.headers = {}
}

///| ——————————————————————————————————————————————————————————————————————
///  Additional convenience methods
///| ——————————————————————————————————————————————————————————————————————

///|
/// GetRawData returns the raw request body as a string.
/// See `c.GetRawData()` equivalent.
pub async fn Context::get_raw_data(self : Context) -> String {
  self.body_string()
}

///|
/// GetQueryArray returns all values for a query parameter key.
/// e.g., `?tag=a&tag=b` → `["a", "b"]`
pub fn Context::get_query_array(self : Context, key : String) -> Array[String] {
  let results : Array[String] = []
  // Parse raw query string for duplicate keys
  let qs = match self.req.path.find("?") {
    Some(pos) => self.req.path[pos + 1:].to_owned()
    None => ""
  }
  if qs != "" {
    let pairs = qs.split("&")
    for pair in pairs {
      match pair.find("=") {
        Some(i) => {
          let k = pair[:i].to_owned()
          if k == key {
            results.push(pair[i + 1:].to_owned())
          }
        }
        None => ()
      }
    }
  }
  results
}

///|
/// DefaultQuery returns the query value or a default.
/// See `c.DefaultQuery()` equivalent.
pub fn Context::default_query(
  self : Context,
  key : String,
  default : String,
) -> String {
  match self.query(key) {
    Some(v) => v
    None => default
  }
}

///|
/// QueryMap returns all query parameters as a map.
/// See `c.QueryMap()` equivalent.
pub fn Context::query_map(self : Context) -> Map[String, String] {
  self.parse_query()
  match self.query_cache {
    Some(map) => map
    None => {}
  }
}

///|
/// PostFormMap returns all POST form parameters as a map.
pub async fn Context::post_form_map(self : Context) -> Map[String, String] {
  self.parse_post_form()
  match self.post_form_cache {
    Some(map) => map
    None => {}
  }
}

///|
/// GetPostFormArray returns all values for a post form parameter key.
/// e.g., form with `tag=a&tag=b` → `["a", "b"]`
pub async fn Context::get_post_form_array(
  self : Context,
  key : String,
) -> Array[String] {
  let results : Array[String] = []
  let raw = self.body_string()
  if raw != "" {
    let pairs = raw.split("&")
    for pair in pairs {
      match pair.find("=") {
        Some(i) => {
          let k = url_decode(pair[:i].to_owned())
          if k == key {
            results.push(url_decode(pair[i + 1:].to_owned()))
          }
        }
        None => ()
      }
    }
  }
  results
}

///|
/// AbortWithStatusJSON aborts with a JSON error response.
/// Convenience method combining abort + JSON error response.
pub async fn Context::abort_with_status_json(
  self : Context,
  code : Int,
  message : String,
) -> Unit {
  self.aborted = true
  let body : Json = Json::object({
    "error": Json::string(message),
    "code": Json::number(code.to_double()),
  })
  self.json(code, body)
}

///| ——————————————————————————————————————————————————————————————————————
///  Multipart form file upload
///| ——————————————————————————————————————————————————————————————————————

///|
/// FormFile returns the content of an uploaded file from a multipart form.
/// The file is identified by the form field name.
///
/// Returns `Some(content)` if the file was found, `None` otherwise.
pub async fn Context::form_file(
  self : Context,
  field_name : String,
) -> String? {
  let content_type = self.content_type()
  if !content_type.has_prefix("multipart/form-data") {
    return None
  }
  // Extract boundary from Content-Type
  let boundary = match content_type.find("boundary=") {
    Some(pos) => {
      let start = pos + "boundary=".length()
      content_type[start:].to_owned()
    }
    None => return None
  }
  let body = self.body_string()
  // Simple multipart parsing: find the field in the body
  let field_marker = "name=\"" + field_name + "\""
  match body.find(field_marker) {
    Some(field_pos) => {
      // Find the blank line after headers (separates headers from content)
      let after_headers = match body[field_pos:].find("\r\n\r\n") {
        Some(pos) => field_pos + pos + 4
        None =>
          match body[field_pos:].find("\n\n") {
            Some(pos) => field_pos + pos + 2
            None => return None
          }
      }
      // Find the next boundary after the content
      let boundary_marker = "--" + boundary
      let rest = body[after_headers:]
      match rest.find(boundary_marker) {
        Some(end_pos) => {
          let content = rest[:end_pos].to_owned()
          // Remove trailing \r\n
          let content = if content.has_suffix("\r\n") {
            content[:content.length() - 2].to_owned()
          } else if content.has_suffix("\n") {
            content[:content.length() - 1].to_owned()
          } else {
            content
          }
          Some(content)
        }
        None => None
      }
    }
    None => None
  }
}

///|
/// SaveUploadedFile saves an uploaded file to the specified destination path.
///
/// ```
/// match ctx.form_file("avatar") {
///   Some(content) => ctx.save_uploaded_file(content, "./uploads/avatar.png")
///   None => ctx.abort_with_status(400, "No file uploaded")
/// }
/// ```
pub async fn Context::save_uploaded_file(
  self : Context,
  content : String,
  dst : String,
) -> Unit {
  try {
    @fs.write_file(dst, content)
  } catch {
    _ => self.add_error("Failed to save file to " + dst)
  }
}

///|
/// GetPostFormFile returns the filename from a multipart form file upload.
/// Returns the filename extracted from the Content-Disposition header.
pub async fn Context::get_post_form_file(
  self : Context,
  field_name : String,
) -> String? {
  let content_type = self.content_type()
  if !content_type.has_prefix("multipart/form-data") {
    return None
  }
  let body = self.body_string()
  let field_marker = "name=\"" + field_name + "\""
  match body.find(field_marker) {
    Some(pos) => {
      // Look for filename= in the part headers before the field marker
      let header_section = body[:pos].to_owned()
      match header_section.rev_find("filename=\"") {
        Some(fn_start) => {
          let after_fn = fn_start + "filename=\"".length()
          match body[after_fn:].find("\"") {
            Some(fn_end) => Some(body[after_fn:after_fn + fn_end].to_owned())
            None => None
          }
        }
        None => None
      }
    }
    None => None
  }
}

///|
/// AsciiJSON serializes JSON with ASCII-only characters (escapes non-ASCII).
pub async fn Context::ascii_json(
  self : Context,
  code : Int,
  data : Json,
) -> Unit {
  if self.written {
    return
  }
  self.written = true
  self.status_code = code
  let all_headers = self.headers
  all_headers.set("Content-Type", "application/json")
  self.conn.send_response(code, status_text(code), extra_headers=all_headers)
  let raw = data.stringify()
  // Escape non-ASCII characters to \uXXXX
  let ascii = escape_to_ascii(raw)
  self.conn.write_body(ascii)
  self.conn.end_response()
}

///|
/// Escape non-ASCII chars in a string to \uXXXX format.
fn escape_to_ascii(s : String) -> String {
  let mut result = ""
  let chars = s.to_array()
  for i = 0; i < chars.length(); i = i + 1 {
    let ch = chars[i]
    if ch.to_int() <= 127 {
      result = result + ch.to_string()
    } else {
      let hex = ch.to_int().to_uint().to_string(radix=16)
      result = result + "\\u" + "0".repeat(4 - hex.length()) + hex
    }
  }
  result
}

///|
/// Start a chunked stream response. The response is NOT finalized,
/// allowing multiple `write` calls afterwards; call `end_stream` to finish.
pub async fn Context::stream_start(
  self : Context,
  code : Int,
  content_type : String,
) -> Unit {
  if self.written {
    return
  }
  self.written = true
  self.status_code = code
  let all_headers = self.headers
  all_headers.set("Content-Type", content_type)
  all_headers.set("Transfer-Encoding", "chunked")
  self.conn.send_response(code, status_text(code), extra_headers=all_headers)
}

///|
/// Write raw data to an ongoing stream response.
pub async fn Context::write(self : Context, data : String) -> Unit {
  self.conn.write_body(data)
}

///|
/// End a stream response.
pub async fn Context::end_stream(self : Context) -> Unit {
  self.conn.end_response()
}

///|
/// AbortWithError aborts with a status code and adds an error to the context.
pub async fn Context::abort_with_error(
  self : Context,
  code : Int,
  err : String,
) -> Unit {
  self.add_error(err)
  self.abort_with_status(code, err)
}

///|

///|
/// Simple JSON-to-XML conversion for flat objects.
fn json_to_xml(root : String, json : Json) -> String {
  let mut result = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<" + root + ">"
  match json {
    Json::Object(map) =>
      for k, v in map {
        result = result + "\n  <" + k + ">"
        result = result + escape_xml(json_value_to_string(v))
        result = result + "</" + k + ">"
      }
    _ => result = result + escape_xml(json.stringify())
  }
  result + "\n</" + root + ">"
}

///|
fn json_value_to_string(v : Json) -> String {
  match v {
    Json::String(s) => s
    Json::Number(n, ..) => n.to_string()
    Json::True => "true"
    Json::False => "false"
    Json::Null => ""
    _ => v.stringify()
  }
}

///|
fn escape_xml(s : String) -> String {
  s
  .replace_all(old="&", new="&amp;")
  .replace_all(old="<", new="&lt;")
  .replace_all(old=">", new="&gt;")
  .replace_all(old="\"", new="&quot;")
}

///|
/// Simple JSON-to-YAML conversion. Handles nested objects.
fn json_to_yaml(json : Json, indent~ : Int = 0) -> String {
  let prefix = " ".repeat(indent)
  match json {
    Json::Object(map) => {
      if map.is_empty() {
        "{}"
      } else {
        let mut result = ""
        for k, v in map {
          if result != "" {
            result = result + "\n"
          }
          let val = match v {
            Json::Object(_) => "\n" + json_to_yaml(v, indent=indent + 2)
            Json::Array(arr) => {
              if arr.is_empty() {
                "[]"
              } else {
                let mut items = ""
                for item in arr {
                  if items != "" {
                    items = items + ", "
                  }
                  items = items + json_value_to_string(item)
                }
                "[" + items + "]"
              }
            }
            _ => json_value_to_string(v)
          }
          result = result + prefix + k + ": " + val
        }
        result
      }
    }
    _ => json_value_to_string(json)
  }
}

///| ——————————————————————————————————————————————————————————————————————
///  Remaining API completeness
///| ——————————————————————————————————————————————————————————————————————

///|
/// Keys returns all keys in the context store.
/// See `c.Keys` equivalent.
pub fn Context::keys(self : Context) -> Array[String] {
  let result : Array[String] = []
  for k, _ in self.store {
    result.push(k)
  }
  result
}

///|
/// Error returns the last error in the context's error list.
/// See `c.Errors.Last()` equivalent.
pub fn Context::error(self : Context) -> String? {
  if self.errors.length() > 0 {
    Some(self.errors[self.errors.length() - 1])
  } else {
    None
  }
}

///|
/// BindJSON binds the request body as JSON. On failure, aborts with 400.
/// See `c.BindJSON()` equivalent.
pub async fn[T : @json.FromJson] Context::bind_json_api(self : Context) -> T? {
  let bound : T? = self.should_bind_json()
  match bound {
    Some(v) => Some(v)
    None => {
      self.abort_with_status_json(400, "Invalid JSON body")
      None
    }
  }
}

///|
/// BindQuery binds query parameters. On failure, aborts with 400.
pub async fn[T : @json.FromJson] Context::bind_query_api(self : Context) -> T? {
  let bound : T? = self.should_bind_query()
  match bound {
    Some(v) => Some(v)
    None => {
      self.abort_with_status_json(400, "Invalid query parameters")
      None
    }
  }
}

///|
/// BindForm binds form body. On failure, aborts with 400.
pub async fn[T : @json.FromJson] Context::bind_form_api(self : Context) -> T? {
  let bound : T? = self.should_bind_form()
  match bound {
    Some(v) => Some(v)
    None => {
      self.abort_with_status_json(400, "Invalid form data")
      None
    }
  }
}

///|
/// BindHeader binds request headers. On failure, aborts with 400.
pub async fn[T : @json.FromJson] Context::bind_header_api(self : Context) -> T? {
  let bound : T? = self.should_bind_header()
  match bound {
    Some(v) => Some(v)
    None => {
      self.abort_with_status_json(400, "Invalid headers")
      None
    }
  }
}

///|
/// Render dispatches to the appropriate renderer based on content type.
/// See `c.Render()` equivalent.
pub async fn Context::render(
  self : Context,
  code : Int,
  render_type : RenderType,
  data : Json,
) -> Unit {
  match render_type {
    JSON => self.json(code, data)
    IndentedJSON => self.indented_json(code, data)
    SecureJSON => self.secure_json(code, data)
    AsciiJSON => self.ascii_json(code, data)
    PureJSON => self.pure_json(code, data)
    JSONP => self.jsonp(code, data)
    XML => self.xml(code, data)
    YAML => self.yaml(code, data)
    TOML => self.toml(code, data)
    ProtoBuf => self.proto_buf(code, data)
  }
}

///|
/// Render type enumeration for the Render() method.
pub(all) enum RenderType {
  JSON
  IndentedJSON
  SecureJSON
  AsciiJSON
  PureJSON
  JSONP
  XML
  YAML
  TOML
  ProtoBuf
} derive(Show, Eq)

///|
/// MultipartForm returns the full multipart form data as parsed fields.
/// Returns a map of field name → file content for simple file uploads.
pub async fn Context::multipart_form(self : Context) -> Map[String, String] {
  let content_type = self.content_type()
  if !content_type.has_prefix("multipart/form-data") {
    return {}
  }
  let boundary = match content_type.find("boundary=") {
    Some(pos) => {
      let start = pos + "boundary=".length()
      content_type[start:].to_owned()
    }
    None => return {}
  }
  let body = self.body_string()
  let result : Map[String, String] = {}
  // Parse all parts: find each "name=" field and extract content
  let boundary_marker = "--" + boundary
  let mut search_from = 0
  while search_from < body.length() {
    match body[search_from:].find("name=\"") {
      Some(name_start) => {
        let after_name = search_from + name_start + "name=\"".length()
        match body[after_name:].find("\"") {
          Some(name_end) => {
            let field_name = body[after_name:after_name + name_end].to_owned()
            // Find content after headers
            match body[after_name + name_end:].find("\r\n\r\n") {
              Some(content_start) => {
                let content_pos = after_name + name_end + content_start + 4
                let remaining = body[content_pos:]
                match remaining.find(boundary_marker) {
                  Some(end) => {
                    let content = remaining[:end].to_owned()
                    let content = match content.strip_suffix("\r\n") {
                      Some(v) => v.to_owned()
                      None => content
                    }
                    result.set(field_name, content)
                    search_from = content_pos + end + boundary_marker.length()
                  }
                  None => break
                }
              }
              None => break
            }
          }
          None => break
        }
      }
      None => break
    }
  }
  result
}

///|
/// TOML renders a TOML response (placeholder — returns JSON).
pub async fn Context::toml(self : Context, code : Int, obj : Json) -> Unit {
  if self.written {
    return
  }
  self.written = true
  self.status_code = code
  let all_headers = self.headers
  all_headers.set("Content-Type", "application/toml; charset=utf-8")
  self.conn.send_response(code, status_text(code), extra_headers=all_headers)
  self.conn.write_body(obj.stringify())
  self.conn.end_response()
}

///|
/// ProtoBuf renders a protobuf response (placeholder — returns JSON).
pub async fn Context::proto_buf(self : Context, code : Int, obj : Json) -> Unit {
  if self.written {
    return
  }
  self.written = true
  self.status_code = code
  let all_headers = self.headers
  all_headers.set("Content-Type", "application/protobuf")
  self.conn.send_response(code, status_text(code), extra_headers=all_headers)
  self.conn.write_body(obj.stringify())
  self.conn.end_response()
}
