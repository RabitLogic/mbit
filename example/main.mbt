///|
/// mbit example — demonstrates core features:
/// - Route registration (GET, POST, ANY, path params, wildcard)
/// - Middleware (custom auth, logger, recovery, CORS, rate-limit)
/// - Route groups with nested groups
/// - JSON binding (should_bind) and responses (using H helper)
/// - Content negotiation
/// - Custom 404 / 405 handlers
/// - Default server port

///|
/// Custom auth middleware — checks for an `Authorization` header.
fn auth_mw() -> Handler {
  async fn(ctx) {
    match ctx.header("Authorization") {
      Some(token) => {
        ctx.set("token", Json::string(token))
        ctx.next()
      }
      None => ctx.abort_with_status(401, "Missing Authorization header")
    }
  }
}

///|
/// GET /hello — simple text response
fn handle_hello(ctx : Context) {
  ctx.string(200, "Hello, mbit!")
}

///|
/// GET /hello/:name — path parameter
fn handle_hello_name(ctx : Context) {
  let name = ctx.param_default("name", "world")
  ctx.string(200, "Hello, \{name}!")
}

///|
/// GET /api/json — JSON response using H helper (like gin.H)
fn handle_json(ctx : Context) {
  ctx.json(200, Json::object(h([
    ("framework", Json::string("mbit")),
    ("version", Json::string("0.1.0")),
    ("language", Json::string("MoonBit")),
  ])))
}

///|
/// POST /api/echo — echo back JSON body
async fn handle_echo(ctx : Context) {
  let body = ctx.body_json()
  match body {
    Some(json) => ctx.json(200, json)
    None => ctx.json(400, Json::object(h([
      ("error", Json::string("Invalid JSON")),
    ])))
  }
}

///|
/// ANY /api/health — health check (matches all HTTP methods)
fn handle_health(ctx : Context) {
  ctx.json(200, Json::object(h([
    ("status", Json::string("ok")),
  ])))
}

///|
/// GET /api/protected — requires auth middleware
fn handle_protected(ctx : Context) {
  ctx.json(200, Json::object(h([
    ("message", Json::string("You are authenticated!")),
  ])))
}

///|
/// GET /files/*filepath — wildcard route
fn handle_files(ctx : Context) {
  let filepath = ctx.param_default("filepath", "")
  ctx.string(200, "Requested file: \{filepath}")
}

///|
/// Custom 404 handler
fn handle_404(ctx : Context) {
  ctx.json(404, Json::object(h([
    ("error", Json::string("The page you requested was not found")),
    ("path", Json::string(ctx.path())),
  ])))
}

///|
/// Custom 405 handler
fn handle_405(ctx : Context) {
  ctx.set_header("Allow", "GET, POST")
  ctx.json(405, Json::object(h([
    ("error", Json::string("Method not allowed for this path")),
    ("method", Json::string(ctx.method())),
  ])))
}

///|
/// POST /api/login — should_bind demo (auto-detect content type)
async fn handle_login(ctx : Context) {
  let body = ctx.body_json()
  match body {
    Some(json) => {
      let username = match json.get("username") {
        Some(Json::String(u)) => u
        _ => ""
      }
      if username == "" {
        ctx.json(400, Json::object(h([
          ("error", Json::string("username is required")),
        ])))
        return
      }
      ctx.json(200, Json::object(h([
        ("message", Json::string("Welcome, \{username}!")),
      ])))
    }
    None => ctx.json(400, Json::object(h([
      ("error", Json::string("Invalid JSON body")),
    ])))
  }
}

///|
/// GET /api/query — query parameter demo
fn handle_query(ctx : Context) {
  let search = ctx.query_default("q", "")
  let page = ctx.query_default("page", "1")
  ctx.json(200, Json::object(h([
    ("search", Json::string(search)),
    ("page", Json::string(page)),
  ])))
}

///|
/// GET /api/negotiate — content negotiation demo
fn handle_negotiate(ctx : Context) {
  let data = h([
    ("message", Json::string("Hello from mbit")),
  ])
  match ctx.negotiate_format(["application/json", "text/html"]) {
    Some("application/json") => ctx.json(200, Json::object(data))
    Some("text/html") => ctx.html(
      200,
      "<h1>Hello from mbit</h1>",
    )
    _ => ()  // 406 already set
  }
}

///|
/// GET /api/websocket — WebSocket upgrade check demo
fn handle_ws_info(ctx : Context) {
  if ctx.is_websocket() {
    ctx.string(200, "WebSocket upgrade detected!")
  } else {
    ctx.json(200, Json::object(h([
      ("websocket", Json::string("false")),
      ("hint", Json::string("Add Connection: Upgrade and Upgrade: websocket headers")),
    ])))
  }
}

///|
async fn main {
  // Create engine with logger + recovery
  let app = default()

  // Add CORS
  app.use(cors(CORSConfig::default()))

  // Add request ID and timing headers
  app.use(request_id())
  app.use(timing())

  // Custom error handlers
  app.no_route([handle_404])
  app.no_method([handle_405])

  // === Simple routes ===
  app.get("/hello", [handle_hello])
  app.get("/hello/:name", [handle_hello_name])
  app.get("/files/*filepath", [handle_files])

  // === Any-method routes ===
  app.any("/api/health", [handle_health])

  // === JSON routes ===
  app.get("/api/json", [handle_json])
  app.post("/api/echo", [handle_echo])
  app.post("/api/login", [handle_login])
  app.get("/api/query", [handle_query])

  // === Content negotiation ===
  app.get("/api/negotiate", [handle_negotiate])

  // === WebSocket detection ===
  app.get("/api/websocket", [handle_ws_info])

  // === Route group with auth middleware ===
  let protected = app.group("/api/protected")
  protected.use(auth_mw())
  protected.get("/", [handle_protected])
  protected.get("/admin", [fn(ctx) {
    ctx.json(200, Json::object(h([
      ("role", Json::string("admin")),
    ])))
  }])

  // === Nested route group ===
  let admin = protected.group("/admin")
  admin.get("/dashboard", [fn(ctx) {
    ctx.json(200, Json::object(h([
      ("dashboard", Json::string("admin dashboard")),
    ])))
  }])

  // === Start server on default port 8080 ===
  app.run_default()
}
