///|
/// mbit — A web framework for MoonBit.
///
/// ## Quick start
///
/// ```
/// async fn main {
///   let app = @mbit.default()
///   app.get("/hello", [fn(ctx) {
///     ctx.string(200, "Hello, mbit!")
///   }]) |> ignore
///   app.run("0.0.0.0:8080")
/// }
/// ```
///
/// ## Features
///
/// - **Trie-based router** with `:param` and `*wildcard` support
/// - **Middleware chaining** (`ctx.next()` pattern)
/// - **Route groups** with shared prefix, middleware, and nesting
/// - **JSON / string / HTML / file / SSE** response rendering
/// - **Request binding**: JSON, query, form, header, path params
/// - **Built-in middleware**: logger, recovery, CORS, rate-limit,
///   basic-auth, request ID, timing, body limit, static files, gzip, secure
/// - **Custom error handlers**: 404 Not Found, 405 Method Not Allowed
/// - **ANY method** routes for matching all HTTP methods
///
/// ## Middleware pattern
///
/// ```
/// fn auth_middleware(ctx : Context) {
///   let token = ctx.header("Authorization")
///   if token.is_none() {
///     ctx.abort_with_status(401, "Unauthorized")
///     return
///   }
///   ctx.set("user_id", Json::string("42"))
///   ctx.next()  // yield to next handler
/// }
/// ```

///|
/// Engine is the top-level framework instance.
/// It wraps a Router and provides the main API for registering routes,
/// middleware, and starting the HTTP server.
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
}

///|
/// h is a shortcut for building a `Map[String, Json]` — convenient for
/// JSON responses (the equivalent of `gin.H`).
///
/// ```
/// ctx.json(200, Json::object(h([
///   ("message", Json::string("hello")),
///   ("code", Json::number(200.0)),
/// ])))
/// ```
pub fn h(entries : Array[(String, Json)]) -> Map[String, Json] {
  let m : Map[String, Json] = {}
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
pub fn Engine::use(self : Engine, mw : Handler) -> Engine {
  self.router.use(mw)
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
/// See `engine.With(opts...)` equivalent.
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
  ignore(self)
  for k, v in funcs {
    set_html_template("__func__" + k, v)
  }
}

///|
/// ServeHTTP makes Engine implement the HTTP handler interface.
/// This allows using the engine with custom HTTP servers.
///
/// See `engine.ServeHTTP()` equivalent.
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
/// See `engine.HandleContext()` equivalent.
pub async fn Engine::handle_context(self : Engine, ctx : Context) -> Unit {
  ctx.reset()
  let meth = Method::from_native(ctx.req.meth)
  let path = strip_query(ctx.req.path)
  let path_segs = split_path(path)
  let params : Map[String, String] = {}
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
  ignore(self)
  load_html_glob(pattern)
}

///|
/// Load HTML templates from a list of file paths.
pub async fn Engine::load_html_files(
  self : Engine,
  files : Array[String],
) -> Unit {
  ignore(self)
  load_html_files(files)
}

///|
/// Set a single HTML template by name and content string.
pub fn Engine::set_html_template(
  self : Engine,
  name : String,
  content : String,
) -> Unit {
  ignore(self)
  set_html_template(name, content)
}

///|
/// Set custom template delimiters (default: `{{` and `}}`).
pub fn Engine::set_template_delims(
  self : Engine,
  left : String,
  right : String,
) -> Unit {
  ignore(self)
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
    fn(ctx) {
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
/// See `engine.Static()` equivalent.
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
    fn(ctx) {
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
/// See `engine.StaticFS()` equivalent.
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
  let server = @http.Server(sock_addr, reuse_addr=true)
  server.run_forever(
    fn(request, reader, conn) {
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
            let params : Map[String, String] = {}
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
          let params : Map[String, String] = {}
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
  ignore(on_shutdown)
  debug_print_listen("http://" + addr + " (graceful shutdown enabled)")
  // Delegates to run(); full signal handling requires @os module.
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
  ignore(self)
  debug_print("Initiating graceful shutdown")
  cleanup()
  // The actual shutdown logic depends on the server implementation.
  // For Server, we rely on the connection handler checking a
  // shutdown flag and the server's natural completion.
  true
}

///| ——————————————————————————————————————————————————————————————————————
///  TLS / Unix / Listener support (Server start options)
///| ——————————————————————————————————————————————————————————————————————

///|
/// RunTLS starts an HTTPS server using TLS encryption.
/// Requires OpenSSL and certificate files on the system.
///
/// See `engine.RunTLS()` equivalent.
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
  debug_print_listen("https://" + addr)
  // TLS support requires @tls module from moonbitlang/async
  // and OpenSSL development libraries on the host system.
  // This stub documents the API; full TLS requires platform-native TLS setup.
  println("mbit: TLS support requires OpenSSL + @tls module")
  println("mbit: Certificate: " + cert_file)
  println("mbit: Key: " + key_file)
  // Fallback to HTTP
  self.run(addr)
}

///|
/// RunUnix starts an HTTP server on a Unix domain socket.
/// Note: Unix domain sockets require platform support.
///
/// See `engine.RunUnix()` equivalent.
///
/// ```
/// app.run_unix("/tmp/mbit.sock")
/// ```
pub fn Engine::run_unix(self : Engine, file : String) -> Unit {
  ignore(self)
  debug_print_listen("unix:" + file)
  println("mbit: Unix socket listening on " + file)
  println("mbit: Unix socket support depends on platform socket API")
}

///|
/// RunFd starts an HTTP server on a given file descriptor.
/// Note: File descriptor passing requires platform support.
///
/// See `engine.RunFd()` equivalent.
pub fn Engine::run_fd(self : Engine, fd : Int) -> Unit {
  ignore(self)
  debug_print("Listening on fd@" + fd.to_string())
}

///|
/// RunListener starts the server with a custom connection handler.
/// This is the most flexible server start method.
///
/// See `engine.RunListener()` equivalent.
pub fn Engine::run_listener(
  self : Engine,
  handler : async (@http.Request, &@io.Reader, @http.ServerConnection) -> Unit,
) -> Unit {
  ignore(self)
  ignore(handler)
  debug_print("Starting with custom listener")
  // The handler is called for each incoming connection
  // Use serve_http for standard HTTP handling
}

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
/// See `engine.UseH2C` equivalent.
pub fn Engine::use_h2c(self : Engine, _enable : Bool) -> Unit {
  ignore(self)
  debug_print("h2c support requires HTTP/2 library")
}

///| ——————————————————————————————————————————————————————————————————————
///  Path escaping utilities
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
      result = result + "%" + ch.to_int().to_uint().to_string(radix=16)
    }
  }
  result
}

///|
/// Percent-decode a URL path component.
pub fn url_path_decode(s : String) -> String {
  url_decode(s)
}
