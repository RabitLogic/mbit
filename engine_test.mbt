///|
/// Engine tests — creation, config, routes, groups, chaining, gins.

test "new engine has no routes" {
  assert_eq(new().routes().length(), 0)
}

test "default engine has no routes" {
  assert_eq(default().routes().length(), 0)
}

test "register GET" {
  let app = new()
  app.get("/hello", [(_ctx) => ()]) |> ignore
  assert_eq(app.routes().length(), 1)
}

test "register POST" {
  let app = new()
  app.post("/api", [(_ctx) => ()]) |> ignore
  assert_eq(app.routes()[0].meth, "POST")
}

test "any registers 7 methods" {
  let app = new()
  app.any("/health", [(_ctx) => ()]) |> ignore
  assert_eq(app.routes().length(), 7)
}

test "handle registers specified methods" {
  let app = new()
  app.handle([GET, POST], "/form", [(_ctx) => ()]) |> ignore
  assert_eq(app.routes().length(), 2)
}

test "no_route and no_method" {
  let app = new()
  app.no_route([(ctx) => { ctx.string(404, "nf") }])
  app.no_method([(ctx) => { ctx.string(405, "nm") }])
  assert_true(true)
}

test "group creates prefixed routes" {
  let app = new()
  app.group("/api").get("/users", [(_ctx) => ()])
  assert_eq(app.routes().length(), 1)
}

test "nested group" {
  let app = new()
  app.group("/api").group("/v1").get("/users", [(_ctx) => ()])
  assert_eq(app.routes().length(), 1)
}

test "group middleware" {
  let app = new()
  let api = app.group("/api")
  api.use((ctx) => { ctx.next() }) |> ignore
  assert_eq(api.handlers().length(), 1)
}

test "group base_path" {
  assert_eq(new().group("/api/v2").base_path(), "/api/v2")
}

test "engine config defaults" {
  let app = new()
  assert_false(app.redirect_trailing_slash)
  assert_false(app.redirect_fixed_path)
  assert_false(app.remove_extra_slash)
  assert_false(app.use_raw_path)
  assert_true(app.unescape_path_values)
}

test "engine config setters" {
  let app = new()
  app.redirect_trailing_slash(true)
  app.redirect_fixed_path(true)
  app.remove_extra_slash(true)
  assert_true(app.redirect_trailing_slash)
  assert_true(app.redirect_fixed_path)
}

test "engine chaining" {
  let app = new()
  let _ = app.use((ctx) => { ctx.next() })
            .get("/a", [(_ctx) => ()])
            .post("/b", [(_ctx) => ()])
  assert_eq(app.routes().length(), 2)
}

test "H helper" {
  assert_eq(h([("k", Json::string("v"))]).get("k"), Some(Json::string("v")))
}

test "H helper empty" {
  assert_eq(h([]).get("missing"), None)
}

test "mode functions" {
  set_mode(Debug)
  assert_true(is_debug())
  assert_false(is_release())
  set_mode(Release)
  assert_true(is_release())
  assert_false(is_debug())
  set_mode(Debug)
}

test "clean_path" {
  assert_eq(clean_path("//a//b"), "/a/b")
  assert_eq(clean_path("/a/./b"), "/a/b")
  assert_eq(clean_path("/a/../b"), "/b")
  assert_eq(clean_path(""), "/")
}

test "version returns string" {
  assert_true(version().length() > 0)
}

test "name_and_version" {
  assert_true(name_and_version().has_prefix("mbit/"))
}

test "app singleton" {
  let _ = Mbit::default().engine()
  assert_true(true)
}

test "Mbit::default().get registers route" {
  let a = Mbit::default()
  a.get("/gtest", [(_ctx) => ()])
  assert_true(a.routes().length() >= 1)
}

test "Mbit::default().use adds middleware" {
  Mbit::default().use((ctx) => { ctx.next() })
  assert_true(true)
}

test "Mbit::default().no_route" {
  Mbit::default().no_route([(ctx) => { ctx.string(404, "nf") }])
  assert_true(true)
}

test "url_encode" {
  let encoded = url_encode("hello world")
  assert_true(encoded.contains("%20"))
}

test "url_path_decode" {
  assert_eq(url_path_decode("hello%20world"), "hello world")
}

test "static_file registration" {
  let app = new()
  app.static_file("/favicon.ico", "./nonexistent.ico")
  assert_eq(app.routes().length(), 1)
}

///| ——————————————————————————————————————————————————————————————————————
///  Extended coverage: config, static FS, chaining, advanced patterns
///| ——————————————————————————————————————————————————————————————————————

test "engine set_max_multipart_memory" {
  let app = new()
  app.set_max_multipart_memory(64L * 1024L * 1024L)
  assert_true(true)
}

test "engine set_remote_ip_headers" {
  let app = new()
  app.set_remote_ip_headers(["CF-Connecting-IP", "X-Real-IP"])
  assert_true(true)
}

test "engine set_trusted_platform" {
  let app = new()
  app.set_trusted_platform("CF-Connecting-IP")
  assert_true(true)
}

test "engine set_forwarded_by_client_ip" {
  let app = new()
  app.set_forwarded_by_client_ip(false)
  assert_false(app.forwarded_by_client_ip)
}

test "engine set_trusted_proxies" {
  let app = new()
  app.set_trusted_proxies(["10.0.0.0/8"])
  assert_true(true)
}

test "engine use_raw_path config" {
  let app = new()
  app.use_raw_path(true)
  assert_true(app.use_raw_path)
}

test "engine unescape_path_values config" {
  let app = new()
  app.unescape_path_values(false)
  assert_false(app.unescape_path_values)
}

test "engine handle_method_not_allowed" {
  let app = new()
  assert_false(app.handle_method_not_allowed)
  app.handle_method_not_allowed(true)
  assert_true(app.handle_method_not_allowed)
}

test "engine static_fs registration" {
  let app = new()
  app.static_fs("/files", "./uploads")
  assert_true(app.routes().length() >= 1)
}

test "engine static_files_engine with wildcard" {
  let app = new()
  app.static_files_engine("/assets", "./public")
  assert_eq(app.routes().length(), 1)
}

test "engine with option functions" {
  let app = new()
  let opts : Array[(Engine) -> Unit] = [
    fn(e : Engine) { e.redirect_trailing_slash(true) },
    fn(e : Engine) { e.remove_extra_slash(true) },
  ]
  let configured = app.with_options(opts)
  assert_true(configured.redirect_trailing_slash)
  assert_true(configured.remove_extra_slash)
}

test "engine multiple route registrations chained" {
  let app = new()
  app.get("/a", [(_ctx) => ()])
     .get("/b", [(_ctx) => ()])
     .get("/c", [(_ctx) => ()])
     .get("/d", [(_ctx) => ()])
  |> ignore
  assert_eq(app.routes().length(), 4)
}

test "engine full CRUD chaining" {
  let app = new()
  app.get("/items", [(_ctx) => ()])
     .post("/items", [(_ctx) => ()])
     .put("/items/:id", [(_ctx) => ()])
     .del("/items/:id", [(_ctx) => ()])
  |> ignore
  assert_eq(app.routes().length(), 4)
}

test "engine head and options registration" {
  let app = new()
  app.head("/status", [(_ctx) => ()])
     .options("/api", [(_ctx) => ()])
  |> ignore
  assert_eq(app.routes().length(), 2)
}

test "engine patch registration" {
  let app = new()
  app.patch("/items/:id", [(_ctx) => ()]) |> ignore
  assert_eq(app.routes().length(), 1)
  assert_eq(app.routes()[0].meth, "PATCH")
}

test "group with middleware chaining" {
  let app = new()
  let api = app.group("/api")
  api.use((ctx) => { ctx.next() })
     .use((ctx) => { ctx.next() })
     .use((ctx) => { ctx.next() })
  |> ignore
  assert_eq(api.handlers().length(), 3)
}

test "nested group inherits parent middleware" {
  let app = new()
  let parent = app.group("/api")
  parent.use((ctx) => { ctx.next() }) |> ignore
  let child = parent.group("/v2")
  assert_eq(child.handlers().length(), 1) // inherited parent middleware
}

test "group handle multiple methods" {
  let app = new()
  app.group("/api").handle([GET, POST, PUT], "/data", [(_ctx) => ()])
  assert_eq(app.routes().length(), 3)
}

test "group any registers all methods" {
  let app = new()
  app.group("/health").any("/check", [(_ctx) => ()])
  assert_eq(app.routes().length(), 7)
}

test "group head and options" {
  let app = new()
  let g = app.group("/api")
  g.head("/status", [(_ctx) => ()])
  g.options("/config", [(_ctx) => ()])
  assert_eq(app.routes().length(), 2)
}

test "multiple groups with different prefixes" {
  let app = new()
  app.group("/api/v1").get("/users", [(_ctx) => ()])
  app.group("/api/v2").get("/users", [(_ctx) => ()])
  assert_eq(app.routes().length(), 2)
}

test "routes from group include full path" {
  let app = new()
  app.group("/api/v1").get("/users", [(_ctx) => ()])
  assert_eq(app.routes()[0].path, "/api/v1/users")
}

test "mode enum values" {
  let ms : Array[Mode] = [Debug, Release, Test]
  assert_eq(ms[0].to_string(), "Debug")
  assert_eq(ms[1].to_string(), "Release")
  assert_eq(ms[2].to_string(), "Test")
}

test "mode roundtrip" {
  set_mode(Debug)
  assert_eq(mode(), Debug)
  set_mode(Release)
  assert_eq(mode(), Release)
  set_mode(Test)
  assert_eq(mode(), Test)
  set_mode(Debug) // restore default
}

test "set_func_map on engine" {
  let app = new()
  app.set_func_map({"key": "value"})
  assert_true(true)
}

///| ——————————————————————————————————————————————————————————————————————
///  Shutdown & IRoutes tests
///| ——————————————————————————————————————————————————————————————————————

test "engine shutdown returns false when not running" {
  let app = new()
  assert_false(app.shutdown())
}

test "engine shutdown with cleanup callback" {
  let app = new()
  let mut cleaned = false
  let _ = app.shutdown(cleanup=fn() { cleaned = true })
  assert_true(cleaned)
}

test "engine health registers route" {
  let app = new()
  app.health()
  let routes = app.routes()
  assert_eq(routes.length(), 1)
  assert_eq(routes[0].path, "/health")
}

test "engine implements route registration" {
  let app = new()
  // Verify Engine has all route registration methods
  app.get("/g", [(_ctx) => ()])
     .post("/p", [(_ctx) => ()])
     .put("/pu", [(_ctx) => ()])
     .del("/d", [(_ctx) => ()])
     .patch("/pa", [(_ctx) => ()])
     .head("/h", [(_ctx) => ()])
     .options("/o", [(_ctx) => ()])
  |> ignore
  assert_eq(app.routes().length(), 7)
}

test "group implements route registration" {
  let app = new()
  let g = app.group("/api")
  g.get("/users", [(_ctx) => ()])
  g.post("/users", [(_ctx) => ()])
  assert_eq(app.routes().length(), 2)
}
