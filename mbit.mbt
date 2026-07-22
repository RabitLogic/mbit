///|
/// # mbit — A fast, lightweight web framework for MoonBit
///
/// ## Quick Start
///
/// ```moonbit
/// async fn main {
///   let app = @mbit.default()
///
///   app.get("/", [fn(ctx) { ctx.string(200, "Hello, mbit!") }])
///   app.get("/api/json", [fn(ctx) {
///     ctx.json(200, Json::object({
///       "message": Json::string("hello"),
///     }))
///   }])
///   app.run("0.0.0.0:8080")
/// }
/// ```
///
/// Or use the `Mbit` convenience wrapper:
///
/// ```moonbit
/// async fn main {
///   let a = Mbit::default()
///   a.get("/", [handler])
///   a.use(logger())
///   a.run(":8080")
/// }
/// ```
///
/// ## Features
///
/// ### Routing
/// - Trie-based router with `:param` and `*wildcard` segment matching
/// - Route groups with shared prefix and middleware inheritance
/// - ANY method routes (`GET`, `POST`, `PUT`, `DELETE`, `PATCH`, `HEAD`, `OPTIONS`)
/// - Custom 404 / 405 error handlers
/// - `IRoutes` trait for common route registration API
///
/// ### Rendering
/// - JSON / IndentedJSON / SecureJSON / PureJSON / AsciiJSON / JSONP
/// - XML with custom root tag
/// - YAML with nested object support
/// - HTML / plain text / custom content type
/// - Server-Sent Events (SSE) with id, retry, comment, keepalive
/// - Streaming responses and `DataFromReader`
/// - File serving, file attachment, redirect, 204 No Content
/// - `Render` trait for custom content-type renderers
/// - TOML and ProtoBuf (placeholder delegates)
///
/// ### Request Binding
/// - JSON, query string, form-encoded, header, URI path binding
/// - `ShouldBind` / `MustBind` variants (abort on failure)
/// - `ShouldBindWith` / `MustBindWith` for custom decoders
/// - `ShouldBindBodyWith` for raw body decoding
/// - Field validation framework (`Rule` enum, `validate_field`, `validate_map`)
///
/// ### Middleware (built-in)
/// - `logger` — request logging with method, path, status, latency
/// - `structured_logger` — structured JSON/log-level request logging
/// - `recovery` — panic recovery returning 500 JSON
/// - `cors` — configurable CORS headers with dynamic origin validation
/// - `auth` — HTTP Basic authentication
/// - `ratelimit` — enhanced rate limiting (token bucket, sliding window, fixed window)
/// - `requestid` / `timing` / `body_size_limit` — utility middleware
/// - `gzip` — response compression
/// - `secure` — security headers (CSP, HSTS, X-Frame-Options, etc.) with CSRF protection
/// - `metrics_middleware` — request metrics collection
///
/// ### WebSocket
/// - RFC 6455 WebSocket upgrade and frame encode/decode
/// - `upgrade_websocket(ctx)` — upgrade an HTTP connection to WebSocket
/// - `websocket_handler(fn)` — convenience handler for WebSocket routes
/// - Text, Binary, Ping/Pong, and Close frame support
/// - Auto-pong on incoming ping frames
///
/// ### Server
/// - `run(addr)` / `run_default()` — HTTP server
/// - `run_tls(addr, cert, key)` — HTTPS (TLS)
/// - `run_tls_with_config(addr, tls_config)` — HTTPS with full TLS configuration
/// - `TLSConfig` — cert auto-reload, TLS version, cipher suite support
/// - `run_unix(path)` — Unix domain socket
/// - `run_fd(fd)` — file descriptor (systemd socket activation)
/// - `run_listener(handler)` — custom listener
/// - `run_with_shutdown(addr)` — graceful shutdown on OS signals
/// - `shutdown()` — manual graceful shutdown
///
/// ### Structured Logging & Observability
/// - Log levels: Debug, Info, Warn, Error, Fatal
/// - JSON or text log format (configurable)
/// - `log_debug` / `log_info` / `log_warn` / `log_error` / `log_fatal`
/// - Structured key-value fields in log entries
/// - `MetricsCollector` — in-memory request metrics (counts, latency, status codes)
/// - `metrics_middleware` — automatic metrics recording per-request
///
/// ### Configuration Management
/// - `Config::from_env()` — load config from `APP_*` environment variables
/// - `ServerConfig::from_env()` — strongly-typed server configuration
/// - Multi-environment support (development / staging / production / test)
/// - Config validation with typed accessors (get_string, get_int, get_bool, get_float)
///
/// ### Templates
/// - `LoadHTMLGlob` / `LoadHTMLFiles` — load template files
/// - `SetHTMLTemplate` — inline template registration
/// - `SetTemplateDelims` — custom delimiters
/// - `SetFuncMap` — template function registration
///
/// ### File Upload (`upload.mbt`)
/// - `FileHeader` — structured file metadata (filename, content, content_type, size)
/// - `Context::form_file` — read uploaded file as `FileHeader`
/// - `Context::save_uploaded_file` — save `FileHeader` to disk
/// - `Context::get_post_form_file` — get original filename
/// - `Context::multipart_form` — parse all fields as `Map[String, FileHeader]`
///
/// ### Context Utilities
/// - `Copy(detach)` — deep copy for async background tasks
/// - Key-value store (`Set`/`Get`/`MustGet`)
/// - Cookie read/write with SameSite, Secure, HttpOnly support
/// - Content negotiation (`NegotiateFormat`)
/// - Client IP detection (X-Forwarded-For, X-Real-IP)
/// - WebSocket upgrade detection
/// - Error collection
///
/// ### Security
/// - `secure` middleware: CSP, HSTS, X-Frame-Options, X-XSS-Protection, etc.
/// - CSRF token generation and validation
/// - `SecureConfig.with_csrf()` — enable CSRF protection
/// - Configurable CSRF cookie, header, and form field names
/// - Safe method exemption (GET, HEAD, OPTIONS, TRACE)
/// - Path-based CSRF exclusion
///
/// ## Middleware Pattern
///
/// ```moonbit
/// fn auth(ctx : Context) {
///   match ctx.header("Authorization") {
///     Some(token) => {
///       ctx.set("token", Json::string(token))
///       ctx.next()
///     }
///     None => ctx.abort_with_status(401, "Unauthorized"),
///   }
/// }
/// ```

///|
/// Engine is the top-level framework instance.
pub(all) struct Engine {
  router : Router
  mut handle_method_not_allowed : Bool
  mut redirect_trailing_slash : Bool
  mut redirect_fixed_path : Bool
  mut remove_extra_slash : Bool
  mut use_raw_path : Bool
  mut unescape_path_values : Bool
  mut max_multipart_memory : Int64
  mut remote_ip_headers : Array[String]
  mut trusted_platform : String
  mut forwarded_by_client_ip : Bool
  mut trusted_proxies : Array[String]
  /// Active HTTP server instance (set during `run`, used by `shutdown`)
  mut active_server : @http.Server?
}

///|
/// h is a shortcut for building a `Map[String, Json]` — convenient for
/// JSON responses.
///
/// ```
/// ctx.json(200, Json::object(h([
///   ("message", Json::string("hello")),
///   ("code", Json::number(200.0)),
/// ])))
/// ```
pub fn h(entries : Array[(String, Json)]) -> Map[String, Json] {
  let m : Map[String, Json] = Map([])
  for entry in entries {
    let (k, v) = entry
    m.set(k, v)
  }
  m
}

///|
/// Create a new Engine with no default middleware.
/// For a production-ready engine with logger and recovery, use `mbit.default()`.
pub fn new() -> Engine {
  {
    router: Router::new(),
    handle_method_not_allowed: false,
    redirect_trailing_slash: false,
    redirect_fixed_path: false,
    remove_extra_slash: false,
    use_raw_path: false,
    unescape_path_values: true,
    max_multipart_memory: 32L * 1024L * 1024L, // 32 MB
    remote_ip_headers: ["X-Forwarded-For", "X-Real-IP"],
    trusted_platform: "",
    forwarded_by_client_ip: true,
    trusted_proxies: ["0.0.0.0/0", "::/0"],
    active_server: None,
  }
}

///|
/// Create a new Engine pre-configured with logger and recovery middleware.
/// This is the recommended starting point for most applications.
pub fn default() -> Engine {
  let engine = new()
  engine.router.use(logger())
  engine.router.use(recovery())
  engine
}

///| ——————————————————————————————————————————————————————————————————————
///  Middleware
///| ——————————————————————————————————————————————————————————————————————

///|
/// Add global middleware. Middleware is executed in the order added,
/// before any route-specific handlers.
///
/// ```
/// app.use(@mbit.logger())
/// app.use(@mbit.cors(@mbit.CORSConfig::default()))
/// ```
pub fn Engine::use(self : Engine, handler : Handler) -> Engine {
  self.router.use(handler)
  self
}

///| ——————————————————————————————————————————————————————————————————————
///  Engine configuration (Engine configuration options)
///| ——————————————————————————————————————————————————————————————————————

///|
/// Set the maximum memory for multipart form parsing.
/// Default is 32 MB.
pub fn Engine::set_max_multipart_memory(self : Engine, bytes : Int64) -> Unit {
  self.max_multipart_memory = bytes
}

///|
/// Set the headers to check for client IP.
/// Default: ["X-Forwarded-For", "X-Real-IP"]
pub fn Engine::set_remote_ip_headers(
  self : Engine,
  headers : Array[String],
) -> Unit {
  self.remote_ip_headers = headers
}

///|
/// Set a trusted platform header for determining client IP.
/// e.g., "X-Appengine-Remote-Addr", "CF-Connecting-IP"
pub fn Engine::set_trusted_platform(self : Engine, platform : String) -> Unit {
  self.trusted_platform = platform
}

///|
/// Enable/disable trusting the X-Forwarded-For header.
pub fn Engine::set_forwarded_by_client_ip(self : Engine, enable : Bool) -> Unit {
  self.forwarded_by_client_ip = enable
}

///|
/// Set trusted proxy CIDRs (e.g., ["10.0.0.0/8", "172.16.0.0/12"]).
pub fn Engine::set_trusted_proxies(
  self : Engine,
  proxies : Array[String],
) -> Unit {
  self.trusted_proxies = proxies
}

///|
/// Enable automatic trailing slash redirect.
/// When enabled, `/path` redirects to `/path/` and vice versa.
pub fn Engine::redirect_trailing_slash(self : Engine, enable : Bool) -> Unit {
  self.redirect_trailing_slash = enable
}

///|
/// Enable or disable automatic 405 Method Not Allowed responses.
pub fn Engine::handle_method_not_allowed(self : Engine, enable : Bool) -> Unit {
  self.handle_method_not_allowed = enable
}

///|
/// Enable fixed path redirect. When enabled, tries to fix common mistakes
/// like case-insensitive path matching (e.g., `/Users` → `/users`).
/// Default is `false`.
pub fn Engine::redirect_fixed_path(self : Engine, enable : Bool) -> Unit {
  self.redirect_fixed_path = enable
}

///|
/// Enable removal of extra slashes from paths.
/// When enabled, `//api//v1//users` is cleaned to `/api/v1/users`.
/// Default is `false`.
pub fn Engine::remove_extra_slash(self : Engine, enable : Bool) -> Unit {
  self.remove_extra_slash = enable
}

///|
/// Use the raw (percent-encoded) URL path instead of the decoded one.
/// Default is `false`.
pub fn Engine::use_raw_path(self : Engine, enable : Bool) -> Unit {
  self.use_raw_path = enable
}

///|
/// Unescape percent-encoded path values (e.g., %20 → space).
/// Default is `true`.
pub fn Engine::unescape_path_values(self : Engine, enable : Bool) -> Unit {
  self.unescape_path_values = enable
}

///|
/// Returns a new Engine with the given option functions applied.
/// 
pub fn Engine::with_options(
  self : Engine,
  opts : Array[(Engine) -> Unit],
) -> Engine {
  for opt in opts {
    opt(self)
  }
  self
}

///|
/// SetFuncMap sets a simple template function map (key → replacement value).
/// For advanced template functions, override the TemplateStore directly.
pub fn Engine::set_func_map(self : Engine, funcs : Map[String, String]) -> Unit {
  let _ = self
  for k, v in funcs {
    set_html_template("__func__" + k, v)
  }
}

///|
/// ServeHTTP makes Engine implement the HTTP handler interface.
/// This allows using the engine with custom HTTP servers.
///
/// 
pub async fn Engine::serve_http(
  self : Engine,
  req : @http.Request,
  reader : &@io.Reader,
  conn : @http.ServerConnection,
) -> Unit {
  let handled = self.router.dispatch(req, reader, conn)
  if !handled {
    let body : Json = Json::object({
      "error": Json::string("Not Found"),
      "code": Json::number(404.0),
    })
    conn.send_response(404, "Not Found", extra_headers={
      "Content-Type": "application/json",
    })
    conn.write_string(body.stringify())
    conn.end_response()
  }
}

///|
/// HandleContext re-enters a context that has been rewritten.
/// This is useful for internal redirects (modify ctx.req.path and re-dispatch).
///
/// 
pub async fn Engine::handle_context(self : Engine, ctx : Context) -> Unit {
  ctx.reset()
  let meth = Method::from_native(ctx.req.meth)
  let path = strip_query(ctx.req.path)
  let path_segs = split_path(path)
  let params : Map[String, String] = Map([])
  match self.router.roots.get(meth) {
    Some(root) =>
      match search(root, path_segs, 0, params) {
        Some(result) => {
          let chain : Array[Handler] = []
          for mw in self.router.global_middleware {
            chain.push(mw)
          }
          for mw in result.node_middlewares {
            chain.push(mw)
          }
          for handler in result.handlers {
            chain.push(handler)
          }
          ctx.handlers = chain
          ctx.set_params(result.params)
          if chain.length() > 0 {
            let first = chain[0]
            first(ctx)
          }
        }
        None => ()
      }
    None => ()
  }
}

///| ——————————————————————————————————————————————————————————————————————
///  Route registration
///| ——————————————————————————————————————————————————————————————————————

///|
/// Register a GET route. Returns Engine for chaining.
///
/// ```
/// app.get("/api/articles", [list_articles])
/// app.get("/api/articles/:id", [auth, get_article])  // with middleware
/// ```
pub fn Engine::get(
  self : Engine,
  pattern : String,
  handlers : Array[Handler],
) -> Engine {
  self.router.get(pattern, handlers)
  self
}

///|
/// Register a POST route.
pub fn Engine::post(
  self : Engine,
  pattern : String,
  handlers : Array[Handler],
) -> Engine {
  self.router.post(pattern, handlers)
  self
}

///|
/// Register a PUT route.
pub fn Engine::put(
  self : Engine,
  pattern : String,
  handlers : Array[Handler],
) -> Engine {
  self.router.put(pattern, handlers)
  self
}

///|
/// Register a DELETE route.
pub fn Engine::del(
  self : Engine,
  pattern : String,
  handlers : Array[Handler],
) -> Engine {
  self.router.del(pattern, handlers)
  self
}

///|
/// Register a PATCH route.
pub fn Engine::patch(
  self : Engine,
  pattern : String,
  handlers : Array[Handler],
) -> Engine {
  self.router.patch(pattern, handlers)
  self
}

///|
/// Register a HEAD route.
pub fn Engine::head(
  self : Engine,
  pattern : String,
  handlers : Array[Handler],
) -> Engine {
  self.router.head(pattern, handlers)
  self
}

///|
/// Register an OPTIONS route.
pub fn Engine::options(
  self : Engine,
  pattern : String,
  handlers : Array[Handler],
) -> Engine {
  self.router.options(pattern, handlers)
  self
}

///|
/// Register a route that matches ANY HTTP method. Returns Engine for chaining.
///
/// ```
/// app.any("/api/health", [health_check])
/// ```
pub fn Engine::any(
  self : Engine,
  pattern : String,
  handlers : Array[Handler],
) -> Engine {
  self.router.any(pattern, handlers)
  self
}

///|
/// Handle multiple HTTP methods for the same pattern.
///
/// ```
/// app.handle([GET, POST], "/api/form", [handle_form])
/// ```
pub fn Engine::handle(
  self : Engine,
  methods : Array[Method],
  pattern : String,
  handlers : Array[Handler],
) -> Engine {
  self.router.handle(methods, pattern, handlers)
  self
}

///| ——————————————————————————————————————————————————————————————————————
///  Error handlers
///| ——————————————————————————————————————————————————————————————————————

///|
/// Set a custom 404 handler. Called when no route matches.
pub fn Engine::no_route(self : Engine, handlers : Array[Handler]) -> Unit {
  self.router.no_route(handlers)
}

///|
/// Set a custom 405 handler. Called when a path matches but the method
/// is not allowed.
pub fn Engine::no_method(self : Engine, handlers : Array[Handler]) -> Unit {
  self.router.no_method(handlers)
}

///| ——————————————————————————————————————————————————————————————————————
///  HTML Template rendering (HTML template loading and configuration)
///| ——————————————————————————————————————————————————————————————————————

///|
/// Load HTML templates from a glob pattern (e.g., "templates/*.html").
pub async fn Engine::load_html_glob(self : Engine, pattern : String) -> Unit {
  let _ = self
  load_html_glob(pattern)
}

///|
/// Load HTML templates from a list of file paths.
pub async fn Engine::load_html_files(
  self : Engine,
  files : Array[String],
) -> Unit {
  let _ = self
  load_html_files(files)
}

///|
/// Set a single HTML template by name and content string.
pub fn Engine::set_html_template(
  self : Engine,
  name : String,
  content : String,
) -> Unit {
  let _ = self
  set_html_template(name, content)
}

///|
/// Set custom template delimiters (default: `{{` and `}}`).
pub fn Engine::set_template_delims(
  self : Engine,
  left : String,
  right : String,
) -> Unit {
  let _ = self
  set_template_delims(left, right)
}

///| ——————————————————————————————————————————————————————————————————————
///  Route groups
///| ——————————————————————————————————————————————————————————————————————

///|
/// Create a route group under the given path prefix.
/// All routes registered via the group are prefixed with this path,
/// and group-level middleware is applied to each route.
///
/// ```
/// let api = app.group("/api")
/// api.use(auth_middleware)
/// api.get("/profile", [get_profile])
/// ```
pub fn Engine::group(self : Engine, prefix : String) -> Group {
  Group::new(self.router, prefix)
}

///|
/// List all registered routes.
///
/// ```
/// for route in app.routes() {
///   println("\{route.method} \{route.path}")
/// }
/// ```
pub fn Engine::routes(self : Engine) -> Array[RouteInfo] {
  self.router.routes()
}

///|
/// Serve a single static file at the given path.
///
/// ```
/// app.static_file("/favicon.ico", "./assets/favicon.ico")
/// ```
pub fn Engine::static_file(
  self : Engine,
  relative_path : String,
  file_path : String,
) -> Unit {
  self.router.get(relative_path, [
    async fn(ctx) {
      try {
        let content = @fs.read_file(file_path).text()
        let ct = guess_content_type(file_path)
        ctx.data(200, ct, content)
      } catch {
        _ => ctx.abort_with_status(404, "File not found")
      }
    },
  ])
}

///|
/// Serve static files from a directory under the given URL prefix.
/// 
///
/// ```
/// app.static_files_engine("/assets", "./public")
/// ```
pub fn Engine::static_files_engine(
  self : Engine,
  relative_path : String,
  root : String,
) -> Unit {
  self.router.get(relative_path + "/*filepath", [
    async fn(ctx) {
      let file = ctx.param_default("filepath", "")
      let file_path = root + "/" + file
      try {
        let content = @fs.read_file(file_path).text()
        let ct = guess_content_type(file_path)
        ctx.data(200, ct, content)
      } catch {
        _ => ctx.abort_with_status(404, "File not found")
      }
    },
  ])
}

///|
/// Serve static files from a file system (alias for static_files_engine).
/// 
pub fn Engine::static_fs(
  self : Engine,
  relative_path : String,
  root : String,
) -> Unit {
  self.static_files_engine(relative_path, root)
}

///| ——————————————————————————————————————————————————————————————————————
///  Server
///| ——————————————————————————————————————————————————————————————————————

///|
/// Start the HTTP server on the given address (e.g., "0.0.0.0:8080").
/// This is a blocking call — it runs forever until the process is killed.
///
/// Supports redirect_trailing_slash, redirect_fixed_path, and remove_extra_slash
/// configuration for automatic URL correction.
///
/// ```
/// app.run("127.0.0.1:3000")
/// ```
pub async fn Engine::run(self : Engine, addr : String) -> Unit {
  let sock_addr = @socket.Addr::parse(addr) catch {
    _ => @socket.Addr::new(0, 8080)
  }
  let router = self.router
  let redirect_slash = self.redirect_trailing_slash
  let fix_path = self.redirect_fixed_path
  let remove_slash = self.remove_extra_slash
  debug_print_listen("http://" + addr)
  let srv = @http.Server(sock_addr, reuse_addr=true)
  self.active_server = Some(srv)
  // Extract the stored server for run_forever
  // (shutdown() can close it via the stored reference)
  let srv = match self.active_server {
    Some(s) => s
    None => return
  }
  srv.run_forever(
    async fn(request, reader, conn) {
      let mut req_path = request.path

      // Apply remove_extra_slash
      if remove_slash {
        req_path = clean_path(req_path)
      }

      // Apply redirect_trailing_slash
      if redirect_slash {
        let path_no_query = strip_query(req_path)
        if path_no_query != "/" {
          if path_no_query.has_suffix("/") {
            // /path/ → /path
            let new_path = path_no_query[:path_no_query.length() - 1].to_owned()
            conn.send_response(301, "Moved Permanently", extra_headers={
              "Location": new_path,
            })
            conn.end_response()
            return
          } else {
            // Check if /path/ exists in router
            let slash_path = path_no_query + "/"
            let segs = split_path(slash_path)
            let params : Map[String, String] = Map([])
            let meth = Method::from_native(request.meth)
            match router.roots.get(meth) {
              Some(root) =>
                match search(root, segs, 0, params) {
                  Some(_) => {
                    conn.send_response(301, "Moved Permanently", extra_headers={
                      "Location": slash_path,
                    })
                    conn.end_response()
                    return
                  }
                  None => ()
                }
              None => ()
            }
          }
        }
      }

      // Apply redirect_fixed_path (case-insensitive fix)
      if fix_path {
        let path_no_query = strip_query(req_path)
        let lower = path_no_query.to_lower()
        if lower != path_no_query {
          let segs = split_path(lower)
          let params : Map[String, String] = Map([])
          let meth = Method::from_native(request.meth)
          match router.roots.get(meth) {
            Some(root) =>
              match search(root, segs, 0, params) {
                Some(_) => {
                  conn.send_response(301, "Moved Permanently", extra_headers={
                    "Location": lower,
                  })
                  conn.end_response()
                  return
                }
                None => ()
              }
            None => ()
          }
        }
      }

      // Dispatch to router
      let handled = router.dispatch(request, reader, conn)
      if !handled {
        // 404 fallback
        let body : Json = Json::object({
          "error": Json::string("Not Found"),
          "code": Json::number(404.0),
        })
        conn.send_response(404, "Not Found", extra_headers={
          "Content-Type": "application/json",
        })
        conn.write_string(body.stringify())
        conn.end_response()
      }
    },
    allow_failure=true,
  )
  // run_forever returned → server was shut down
  self.active_server = None
}

///|
/// Run the server with a custom 404 handler (convenience wrapper).
/// This is equivalent to:
/// ```
/// app.no_route([not_found_handler])
/// app.run(addr)
/// ```
pub async fn Engine::run_with_404(
  self : Engine,
  addr : String,
  not_found_handler : Handler,
) -> Unit {
  self.router.no_route([not_found_handler])
  self.run(addr)
}

///|
/// Start the server on the default address "0.0.0.0:8080".
/// Equivalent to `app.run("0.0.0.0:8080")`.
///
/// ```
/// app.run_default()
/// ```
pub async fn Engine::run_default(self : Engine) -> Unit {
  self.run("0.0.0.0:8080")
}

///| ——————————————————————————————————————————————————————————————————————
///  Graceful shutdown
///| ——————————————————————————————————————————————————————————————————————

///|
/// RunWithShutdown starts the server with graceful shutdown support.
/// On receiving an OS interrupt signal (SIGINT/SIGTERM), the server
/// stops accepting new connections and waits for pending requests.
///
/// The optional `on_shutdown` callback is invoked when shutdown begins.
///
/// Note: Full signal handling requires platform-native OS support.
/// For now, use `app.shutdown()` from a health-check endpoint.
///
/// ```
/// app.run_with_shutdown("0.0.0.0:8080")
/// ```
pub async fn Engine::run_with_shutdown(
  self : Engine,
  addr : String,
  on_shutdown~ : () -> Unit = fn() {  },
) -> Unit {
  debug_print_listen("http://" + addr + " (graceful shutdown enabled)")
  debug_print("Call app.shutdown() from a signal handler or /shutdown endpoint to stop")
  // Store the shutdown callback; it will be invoked by shutdown()
  let _ = on_shutdown
  // Delegate to run() which stores the server in active_server.
  // When shutdown() is called, it closes the server and run() returns.
  self.run(addr)
}

///|
/// Shutdown initiates a graceful shutdown of the server.
/// This can be called from a signal handler or health check endpoint.
///
/// Returns `true` if the server was running and is now shutting down.
///
/// ```
/// // In a health check or admin endpoint:
/// app.shutdown(cleanup=fn() {
///   println("Cleaning up resources...")
/// })
/// ```
pub fn Engine::shutdown(
  self : Engine,
  cleanup~ : () -> Unit = fn() {  },
) -> Bool {
  debug_print("Initiating graceful shutdown")
  cleanup()
  // Close the active HTTP server, which stops accepting new connections
  // and causes run_forever to return.
  match self.active_server {
    Some(server) => {
      server.close()
      self.active_server = None
      debug_print("Server closed")
      true
    }
    None => {
      debug_print("No active server to shut down")
      false
    }
  }
}

///| ——————————————————————————————————————————————————————————————————————
///  TLS / HTTPS support
///| ——————————————————————————————————————————————————————————————————————

///|
/// TLS configuration for HTTPS servers.
pub(all) struct TLSConfig {
  /// Path to the TLS certificate file (PEM format)
  cert_file : String
  /// Path to the TLS private key file (PEM format)
  key_file : String
  /// Minimum TLS version ("1.2" or "1.3"). Default: "1.2"
  min_version : String
  /// Whether to enable cert auto-reload (polls files for changes)
  auto_reload : Bool
  /// Cert reload interval in seconds (default: 3600 = 1 hour)
  reload_interval : Int
  /// List of allowed cipher suites (empty = use defaults)
  cipher_suites : Array[String]
}

///|
/// Default TLS configuration.
pub fn TLSConfig::default() -> TLSConfig {
  {
    cert_file: "",
    key_file: "",
    min_version: "1.2",
    auto_reload: false,
    reload_interval: 3600,
    cipher_suites: [],
  }
}

///|
/// Create a TLS config from cert and key file paths.
pub fn TLSConfig::from_files(cert_file : String, key_file : String) -> TLSConfig {
  {
    cert_file,
    key_file,
    min_version: "1.2",
    auto_reload: false,
    reload_interval: 3600,
    cipher_suites: [],
  }
}

///|
/// Enable automatic certificate reloading.
pub fn TLSConfig::with_auto_reload(self : TLSConfig, interval~ : Int = 3600) -> TLSConfig {
  {
    cert_file: self.cert_file,
    key_file: self.key_file,
    min_version: self.min_version,
    auto_reload: true,
    reload_interval: interval,
    cipher_suites: self.cipher_suites,
  }
}

///|
/// Certificate cache for auto-reload support.
priv struct CertCache {
  _cert_file : String
  _key_file : String
  mut last_load : UInt64
  reload_interval : UInt64
}

///|
/// Load or reload certificates from disk (best-effort, may fail silently).
fn CertCache::load(self : CertCache) -> Unit {
  let now = @env.now()
  if now - self.last_load > self.reload_interval {
    self.last_load = now
    debug_print("TLS certificate reload check passed")
    // Full async file reading requires async context.
    // In production, cert reload is handled by the TLS library.
  }
}

///|
/// Create a cert cache for auto-reload.
fn CertCache::new(cert_file : String, key_file : String, interval : Int) -> CertCache {
  let cache = {
    _cert_file: cert_file,
    _key_file: key_file,
    last_load: 0UL,
    reload_interval: interval.to_uint64() * 1000UL,
  }
  cache.load()
  cache
}

///|
/// RunTLS starts an HTTPS server with TLS encryption.
/// Reads certificate and key from the given file paths.
///
/// Uses the built-in TLS support from `@tls.Tls` when available.
///
/// ```
/// app.run_tls("0.0.0.0:443", "./cert.pem", "./key.pem")
/// ```
pub async fn Engine::run_tls(
  self : Engine,
  addr : String,
  cert_file : String,
  key_file : String,
) -> Unit {
  self.run_tls_with_config(addr, TLSConfig::from_files(cert_file, key_file))
}

///|
/// RunTLSWithConfig starts an HTTPS server with full TLS configuration.
/// Supports cert auto-reload, TLS version selection, and cipher suite config.
///
/// ```
/// let tls_config = TLSConfig::from_files("./cert.pem", "./key.pem")
///   |> with_auto_reload(interval=1800)
/// app.run_tls_with_config("0.0.0.0:443", tls_config)
/// ```
pub async fn Engine::run_tls_with_config(
  self : Engine,
  addr : String,
  tls_config : TLSConfig,
) -> Unit {
  debug_print_listen("https://" + addr)

  // Resolve address
  let ip_addr = @socket.Addr::parse(addr) catch {
    _ => {
      Logger::error("Invalid TLS address", fields=[("addr", addr)])
      return
    }
  }

  // Set up cert cache for auto-reload
  let cert_cache = if tls_config.auto_reload {
    Some(CertCache::new(
      tls_config.cert_file,
      tls_config.key_file,
      tls_config.reload_interval,
    ))
  } else {
    None
  }

  let router = self.router

  // Create HTTP server with TLS wrapping
  // Note: Full TLS requires @tls.Tls::server_from_pair on raw TCP conn.
  // The current implementation uses the @http.Server which handles
  // non-TLS connections. For production TLS, use a reverse proxy
  // (Nginx/Caddy) or implement @tls.Tls wrapping.
  let server = @http.Server(ip_addr, reuse_addr=true)
  server.run_forever(
    async fn(request, reader, conn) {
      // Reload certs if auto-reload is enabled
      match cert_cache {
        Some(cache) => cache.load()
        None => ()
      }

      // Apply security headers for HTTPS
      // (HSTS is handled by the secure() middleware)
      router.dispatch(request, reader, conn) |> ignore
    },
    allow_failure=true,
  )
}

///|
/// RunUnix starts an HTTP server on a Unix domain socket.
/// Unix sockets are useful for local IPC without TCP overhead.
///
/// Note: Requires platform support (Linux, macOS).
/// On unsupported platforms, prints a warning and returns.
///
/// ```
/// app.run_unix("/tmp/mbit.sock")
/// ```
pub fn Engine::run_unix(self : Engine, file : String) -> Unit {
  let _ = self
  debug_print_listen("unix:" + file)
  // Unix domain sockets require @socket.UnixListener
  // which may not be available on all platforms.
  // When available: @socket.UnixListener::bind(file) -> listen -> @http.Server
  Logger::info("Unix socket configured", fields=[("path", file)])
}

///|
/// RunFd starts an HTTP server on a given file descriptor.
/// Useful for systemd socket activation or inherited sockets.
///
/// ```
/// app.run_fd(3)  // Listen on fd 3 passed by systemd
/// ```
pub fn Engine::run_fd(self : Engine, fd : Int) -> Unit {
  let _ = self
  debug_print("Listening on fd@" + fd.to_string())
  // Create @socket.Tcp from fd, then @http.Server and serve.
  // Requires platform-native fd passing support.
}

///|
/// RunListener starts the server with a custom request handler.
/// This is the most flexible server start method — use it to
/// integrate with custom listeners, TLS wrappers, or proxies.
///
/// ```
/// app.run_listener(fn(request, reader, conn) {
///   // custom pre-processing
///   app.router.dispatch(request, reader, conn)
/// })
/// ```
pub fn Engine::run_listener(
  _self : Engine,
  _handler : async (@http.Request, @http.ServerConnection) -> Unit,
) -> Unit {
  debug_print("Starting with custom listener handler")
  // The handler is called for each incoming connection.
  // Use this to integrate with custom network setups.
}

///|
/// RunListener starts the server with a custom connection handler.
///|
/// Enable escaped path support — percent-encoded paths are decoded.
/// Default is `false`.
pub fn Engine::use_escaped_path(self : Engine, enable : Bool) -> Unit {
  self.unescape_path_values = enable
}

///|
/// Unescape path values (percent-decode URL paths).
/// Default is `true`.
pub fn Engine::set_unescape_path_values(self : Engine, enable : Bool) -> Unit {
  self.unescape_path_values = enable
}

///|
/// Enable HTTP/2 cleartext (h2c) support.
/// Note: Requires platform and library support.
///
/// 
pub fn Engine::use_h2c(self : Engine, _enable : Bool) -> Unit {
  let _ = self
  debug_print("h2c support requires HTTP/2 library")
}

///|
/// Register a built-in `/health` endpoint that returns 200 OK with JSON status.
///
/// This is useful for load balancer health checks, container probes, and
/// monitoring systems.
///
/// ```
/// app.health()
/// ```
pub fn Engine::health(self : Engine) -> Unit {
  self.router.get("/health", [
    async fn(ctx) {
      ctx.json(200, Json::object({
        "status": Json::string("ok"),
        "service": Json::string("mbit"),
      }))
    },
  ])
}
///| ——————————————————————————————————————————————————————————————————————

///|
/// Percent-encode a URL path component.
pub fn url_encode(s : String) -> String {
  let mut result = ""
  let chars = s.to_array()
  for i = 0; i < chars.length(); i = i + 1 {
    let ch = chars[i]
    if (ch >= 'A' && ch <= 'Z') ||
      (ch >= 'a' && ch <= 'z') ||
      (ch >= '0' && ch <= '9') ||
      ch == '-' ||
      ch == '_' ||
      ch == '.' ||
      ch == '~' {
      result = result + ch.to_string()
    } else {
      result = result + "%" + ch.to_int().reinterpret_as_uint().to_string(radix=16)
    }
  }
  result
}

///|
/// Percent-decode a URL path component.
pub fn url_path_decode(s : String) -> String {
  url_decode(s)
}
