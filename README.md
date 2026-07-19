# mbit

> **mbit** is a MoonBit web framework, transplanted from Gin.
> It brings Gin's trie-based router, middleware chain, and context-centric API to MoonBit,
> reimagined for MoonBit's type system and async model.

A MoonBit web framework.

[![MoonBit](https://img.shields.io/badge/MoonBit-0.10.4-blue)](https://www.moonbitlang.com/)
[![Tests](https://img.shields.io/badge/tests-427%20passed-brightgreen)]()
[![Gin](https://img.shields.io/badge/ported%20from-Gin-brightgreen)](https://github.com/gin-gonic/gin)

## Features

- **Trie-based router** — `:param` and `*wildcard` matching, route groups, custom 404/405
- **Middleware** — logger, recovery, CORS, gzip, auth, rate-limit, secure headers, request ID, timing
- **Rendering** — JSON, XML, YAML, HTML, SSE, streaming, file serving, content negotiation
- **Binding** — JSON, query, form, header, path parameter binding with `FromJson`
- **Validation** — declarative field validation (required, min, max, email, URL, custom)
- **Template** — HTML template rendering with variable substitution
- **Static files** — serve single files or entire directories

## Relationship to Gin

mbit transplants [Gin](https://github.com/gin-gonic/gin) v1.x's architecture and API design into MoonBit. Key mappings:

| Gin (Go) | mbit (MoonBit) |
|----------|----------------|
| `gin.Engine` | `Engine` |
| `gin.Context` | `Context` |
| `gin.HandlerFunc` | `Handler` (`async (Context) -> Unit`) |
| `gin.H` | `H([])` helper |
| `gin.RouterGroup` | `Group` |
| `c.ShouldBindJSON(&obj)` | `bind_json(ctx)` / `ctx.must_bind_json()` |
| `c.Param("id")` | `ctx.param("id")` |
| `c.Query("q")` | `ctx.query("q")` |
| `c.JSON(200, gin.H{...})` | `ctx.json(200, Json::object(H([...])))` |
| `engine.Use(mw)` | `app.use(mw)` |
| `engine.Run(":8080")` | `app.run("0.0.0.0:8080")` |
| `router.Group("/api")` | `app.group("/api")` |
| `gin.Recovery()` | `recovery()` |
| `gin.Logger()` | `logger()` |

Adaptations for MoonBit:
- **Async**: Handlers are `async (Context) -> Unit` instead of synchronous `func(*gin.Context)`
- **Generics**: Binding uses MoonBit's trait system (`FromJson`) rather than reflection
- **No struct tags**: Validation uses explicit `FieldRules` instead of `binding:"required"` tags
- **Immutable by default**: Struct fields use `mut` explicitly; `Map([])` for empty maps

## Quick Start

```moonbit
async fn main {
  let app = @mbit.default()

  app.get("/", [fn(ctx) { ctx.string(200, "Hello, mbit!") }])
  app.get("/hello/:name", [fn(ctx) {
    let name = ctx.param_default("name", "world")
    ctx.string(200, "Hello, " + name + "!")
  }])

  app.run("0.0.0.0:8080")
}
```

## Installation

Add to `moon.pkg`:

```moonbit
import {
  "RabitLogic/mbit",
}
```

## Routing

### Basic Routes

```moonbit
app.get("/users", [handler])
app.post("/users", [handler])
app.put("/users/:id", [handler])
app.delete("/users/:id", [handler])
app.patch("/users/:id", [handler])
app.head("/health", [handler])
app.options("/api", [handler])

// Match all HTTP methods
app.any("/health", [handler])

// Register with explicit methods
app.handle([GET, POST], "/multi", [handler])
```

### Path Parameters

```moonbit
app.get("/users/:id", [fn(ctx) {
  let id = ctx.param("id")               // Some("42")
  let id_int = ctx.param_int("id")       // Some(42)
  let id_str = ctx.param_default("id", "0")
  let all = ctx.params_all()             // Map of all params
}])
```

### Wildcard Routes

```moonbit
app.get("/files/*filepath", [fn(ctx) {
  let path = ctx.param_default("filepath", "")
  ctx.string(200, "Requested: " + path)
}])
```

### Route Groups

```moonbit
let api = app.group("/api")
api.get("/status", [status_handler])
api.post("/login", [login_handler])

// Nested groups
let admin = api.group("/admin")
admin.use(auth_middleware)
admin.get("/dashboard", [dashboard_handler])
```

### Custom Error Handlers

```moonbit
app.no_route([fn(ctx) {
  ctx.json(404, Json::object({"error": Json::string("Not Found")}))
}])
app.no_method([fn(ctx) {
  ctx.json(405, Json::object({"error": Json::string("Method Not Allowed")}))
}])
```

### Redirects & Path Options

```moonbit
app.redirect_trailing_slash(true)     // /foo/ → /foo
app.redirect_fixed_path(true)         // case-insensitive fix
app.remove_extra_slash(true)          // //foo → /foo
app.handle_method_not_allowed(false)  // disable 405
```

## Middleware

### Built-in Middleware

| Middleware | Description |
|------------|-------------|
| `logger()` | Logs method, path, status, latency |
| `recovery()` | Catches panics, returns 500 |
| `cors(config)` | CORS headers |
| `gzip(config)` | Response compression |
| `request_id()` | `X-Request-Id` header |
| `timing()` | `X-Response-Time` header |
| `secure(config)` | Security headers (helmet-like) |
| `auth()` | Basic auth |
| `rate_limit(config)` | IP-based rate limiting |
| `body_size_limit(bytes)` | Reject large payloads |

### Using Middleware

```moonbit
// Global middleware (applies to all routes)
app.use(logger())
app.use(recovery())
app.use(cors(CORSConfig::default()))

// Group middleware (applies to routes in that group)
let api = app.group("/api")
api.use(auth())
api.use(rate_limit(RateLimitConfig::{ max_requests: 100, window_secs: 60 }))
```

### Logger

```moonbit
app.use(logger())
// Output: [mbit] GET /api/users -> 200 (12ms)
```

### CORS

```moonbit
app.use(cors(CORSConfig::{
  allow_origins: ["https://example.com"],
  allow_methods: ["GET", "POST"],
  allow_headers: ["Content-Type", "Authorization"],
  allow_credentials: true,
  max_age: 3600,
  expose_headers: ["Content-Length"],
}))
```

### Gzip

```moonbit
app.use(gzip(GzipConfig::{ min_length: 512, level: 6 }))
```

### Rate Limiting

```moonbit
app.use(rate_limit(RateLimitConfig::{
  max_requests: 50,
  window_secs: 60,
}))
```

### Secure Headers

```moonbit
app.use(secure(SecureConfig::default()))
// Sets: X-Frame-Options, X-Content-Type-Options, X-XSS-Protection,
//       Content-Security-Policy, Referrer-Policy
```

### Custom Middleware

```moonbit
fn auth_mw() -> Handler {
  async fn(ctx) {
    match ctx.header("Authorization") {
      Some(token) => {
        ctx.set("token", Json::string(token))  // store for downstream handlers
        ctx.next()                              // continue the chain
      }
      None => ctx.abort_with_status(401, "Unauthorized")
    }
  }
}

app.use(auth_mw())
```

## Context

The `Context` carries everything about the current request.

### Request Info

```moonbit
ctx.http_method()       // "GET", "POST", etc.
ctx.path()              // "/users/42"
ctx.full_path()         // "/users/42?page=1"
ctx.client_ip()         // client IP address
ctx.content_type()      // "application/json"
ctx.header("Accept")    // optional header value
ctx.is_websocket()      // true if upgrade request
```

### Query Parameters

```moonbit
ctx.query("page")               // Some("1")
ctx.query_default("page", "1")  // "1"
ctx.query_int("page")           // Some(1)
ctx.query_int64("id")           // Some(42L)
ctx.query_map()                 // all query params as Map
ctx.query_array("tags")         // ["a", "b"] for ?tags=a&tags=b
```

### Request Body

```moonbit
ctx.body_string()       // raw body as string
ctx.body_json()         // parsed as Json

// Form data (application/x-www-form-urlencoded)
ctx.post_form("name")           // Some("Alice")
ctx.default_post_form("name", "unknown")
ctx.post_form_map()             // all form fields
```

### Response Rendering

```moonbit
// JSON
ctx.json(200, Json::object({"message": Json::string("ok")}))
ctx.json_indented(200, data)
ctx.json_secure(200, data)      // with while(1) prefix
ctx.json_pure(200, data)        // no escaping

// XML & YAML
ctx.xml(200, "root", data)
ctx.yaml(200, data)

// HTML & Text
ctx.html(200, "<h1>Hello</h1>")
ctx.string(200, "plain text")

// Redirect
ctx.redirect(301, "/new-path")

// File
ctx.file("path/to/file.pdf")

// SSE (Server-Sent Events)
ctx.sse("event: message\ndata: hello\n\n")

// Streaming
ctx.stream(200, fn(writer) {
  writer("chunk1")
  writer("chunk2")
})
```

### Context Store (Key-Value)

```moonbit
ctx.set("user_id", Json::string("42"))
let user_id = ctx.get("user_id")        // Some(Json::String("42"))
ctx.get_string("user_id")               // Some("42")
```

### Response Headers

```moonbit
ctx.set_header("X-Custom", "value")
ctx.status_code                         // current status (default 200)
ctx.is_written()                        // has response been sent
```

## Binding

Bind request data to structs using `FromJson`.

```moonbit
struct LoginRequest {
  username : String
  password : String
} derive(@json.FromJson)

// JSON body
app.post("/login", [async fn(ctx) {
  let req : LoginRequest? = bind_json(ctx)
  match req {
    Some(r) => ctx.json(200, Json::object({"user": Json::string(r.username)}))
    None => ctx.abort_with_status(400, "Invalid JSON")
  }
}])

// Query string: GET /search?q=hello&page=1
struct SearchQuery {
  q : String
  page : String
} derive(@json.FromJson)
let query = bind_query(ctx)

// Form body
let form = bind_form(ctx)

// Headers
let headers = bind_header(ctx)

// Path params
let params = bind_path(ctx)
```

### MustBind (aborts on failure)

```moonbit
let req = ctx.must_bind_json::[LoginRequest]()   // aborts with 400 on failure
```

## Validation

```moonbit
let rules = [
  FieldRules::new("username", [Required, Min(3), Max(20)]),
  FieldRules::new("email", [Required, Email]),
  FieldRules::new("age", [Min(0), Max(150)]),
]

let errors = validate_map(values, rules)
if errors.length() > 0 {
  ctx.abort_with_status(422, "Validation failed")
  return
}
```

### Available Rules

| Rule | Description |
|------|-------------|
| `Required` | Must not be empty |
| `Min(n)` | Minimum length or numeric value |
| `Max(n)` | Maximum length or numeric value |
| `Len(n)` | Exact length |
| `Pattern(regex)` | Must match pattern |
| `OneOf([...])` | Must be one of the values |
| `Email` | Basic email check |
| `URL` | Basic URL check |
| `Custom(fn)` | Custom validation function |

## Templates

```moonbit
app.set_html_template("welcome", "<html><body>Hello {{.Name}}!</body></html>")
app.set_template_delims("{{", "}}")

// In handler
ctx.html_template("welcome", {"Name": "World"})
```

## Static Files

```moonbit
// Single file
app.static_file("/favicon.ico", "./public/favicon.ico")

// Directory
app.static_("/static", "./public")

// Directory with wildcard
app.static_fs("/assets", "./public")
```

## Server

```moonbit
// Basic
app.run("0.0.0.0:8080")

// Default (logs port)
app.run_default()

// Graceful shutdown
app.run_with_shutdown(":8080", on_shutdown=fn() {
  println("Cleaning up...")
})

// Trigger shutdown from signal handler
app.shutdown()
```

### Debug

```moonbit
let routes = app.routes()
for r in routes {
  println(r.meth + " " + r.path)
}

println(app.trees())  // ASCII tree of the router
```

## Configuration

```moonbit
let engine = Engine::new()
engine.max_multipart_memory(32 * 1024 * 1024)  // 32 MB
engine.redirect_trailing_slash(true)
engine.handle_method_not_allowed(true)
engine.remove_extra_slash(true)
engine.redirect_fixed_path(false)
let app = Mbit::new(engine)
```

## Complete Example

```moonbit
async fn main {
  let app = @mbit.default()

  // Global middleware
  app.use(logger())
  app.use(recovery())
  app.use(cors(CORSConfig::default()))
  app.use(request_id())
  app.use(timing())

  // Custom 404
  app.no_route([fn(ctx) {
    ctx.json(404, Json::object({"error": Json::string("Not Found")}))
  }])

  // Routes
  app.get("/", [fn(ctx) { ctx.string(200, "Hello, mbit!") }])
  app.get("/hello/:name", [fn(ctx) {
    ctx.string(200, "Hello, " + ctx.param_default("name", "world") + "!")
  }])

  app.post("/api/echo", [async fn(ctx) {
    match ctx.body_json() {
      Some(json) => ctx.json(200, json)
      None => ctx.abort_with_status(400, "Invalid JSON")
    }
  }])

  // Protected group
  let api = app.group("/api")
  api.use(fn(ctx) {
    match ctx.header("Authorization") {
      Some(_) => ctx.next()
      None => ctx.abort_with_status(401, "Unauthorized")
    }
  })
  api.get("/users", [list_users])

  // Static files
  app.static_("/static", "./public")

  app.run("0.0.0.0:8080")
}
```

## API Reference

### Mbit

| Method | Description |
|--------|-------------|
| `Mbit::default()` | Create with logger + recovery |
| `Mbit::new(engine)` | Create with custom engine |
| `get/post/put/delete/patch/head/options(path, handlers)` | Route registration |
| `any(path, handlers)` | Match all methods |
| `handle(methods, path, handlers)` | Match specific methods |
| `use(mw)` | Add global middleware |
| `group(prefix)` | Create route group |
| `no_route(handlers)` | 404 handler |
| `no_method(handlers)` | 405 handler |
| `static_file(path, file)` | Serve single file |
| `static_(prefix, root)` | Serve directory |
| `static_fs(prefix, root)` | Serve directory with wildcard |
| `set_html_template(name, content)` | Register template |
| `max_multipart_memory(bytes)` | Set upload limit |
| `redirect_trailing_slash(bool)` | Auto-redirect trailing slashes |
| `handle_method_not_allowed(bool)` | Enable 405 responses |
| `remove_extra_slash(bool)` | Normalize double slashes |
| `run(addr)` | Start server |
| `run_default()` | Start on default port |
| `run_with_shutdown(addr, on_shutdown)` | Start with graceful shutdown |
| `shutdown()` | Trigger shutdown |
| `routes()` | List all routes |
| `trees()` | Print route tree |

### Context

| Method | Returns | Description |
|--------|---------|-------------|
| `http_method()` | `String` | HTTP method |
| `path()` | `String` | Request path |
| `full_path()` | `String` | Path with query string |
| `param(key)` | `String?` | Path parameter |
| `param_default(key, default)` | `String` | Path parameter with fallback |
| `param_int(key)` | `Int?` | Path parameter as Int |
| `param_int64(key)` | `Int64?` | Path parameter as Int64 |
| `params_all()` | `Map[String,String]` | All path params |
| `query(key)` | `String?` | Query parameter |
| `query_default(key, default)` | `String` | Query with fallback |
| `query_int(key)` | `Int?` | Query as Int |
| `query_int64(key)` | `Int64?` | Query as Int64 |
| `query_map()` | `Map[String,String]` | All query params |
| `query_array(key)` | `Array[String]` | Multi-value query |
| `header(key)` | `String?` | Request header |
| `client_ip()` | `String` | Client IP |
| `content_type()` | `String` | Content-Type |
| `body_string()` | `String` | Raw body |
| `body_json()` | `Json?` | Parsed JSON body |
| `post_form(key)` | `String?` | Form field |
| `json(code, data)` | `Unit` | Render JSON |
| `xml(code, root, data)` | `Unit` | Render XML |
| `yaml(code, data)` | `Unit` | Render YAML |
| `html(code, html)` | `Unit` | Render HTML |
| `string(code, text)` | `Unit` | Render plain text |
| `data(code, contentType, body)` | `Unit` | Render custom |
| `redirect(code, url)` | `Unit` | Redirect |
| `file(path)` | `Unit` | Serve file |
| `sse(event)` | `Unit` | SSE event |
| `stream(code, writerFn)` | `Unit` | Stream response |
| `set_header(key, value)` | `Unit` | Set response header |
| `set(key, value)` | `Unit` | Store value |
| `get(key)` | `Json?` | Get stored value |
| `get_string(key)` | `String?` | Get stored string |
| `abort()` | `Unit` | Stop handler chain |
| `abort_with_status(code, msg)` | `Unit` | Abort with JSON error |
| `is_aborted()` | `Bool` | Check if aborted |
| `next()` | `Unit` | Continue to next handler |
| `must_bind_json::[T]()` | `T` | Bind JSON or abort |
| `negotiate_format(offers)` | `String?` | Content negotiation |
| `is_websocket()` | `Bool` | WebSocket upgrade check |

## License

MIT
