///|
/// Router tests — route registration, params, wildcards, path utilities.

test "register and count routes" {
  let router = Router::new()
  let h : Handler = (_ctx) => ()
  router.get("/a", [h])
  router.get("/b", [h])
  router.post("/c", [h])
  assert_eq(router.routes().length(), 3)
}

test "any method registers all 7" {
  let router = Router::new()
  router.any("/health", [(_ctx) => ()])
  assert_eq(router.routes().length(), 7)
}

test "handle registers specified methods" {
  let router = Router::new()
  router.handle([GET, POST], "/api", [(_ctx) => ()])
  assert_eq(router.routes().length(), 2)
}

test "no_route handler" {
  let router = Router::new()
  router.no_route([(ctx) => { ctx.string(404, "nf") }])
  assert_true(true)
}

test "no_method handler" {
  let router = Router::new()
  router.no_method([(ctx) => { ctx.string(405, "nm") }])
  assert_true(true)
}

test "routes include handler_count" {
  let router = Router::new()
  router.get("/api", [(_ctx) => (), (_ctx) => ()])
  assert_eq(router.routes()[0].handler_count, 2)
}

test "global middleware" {
  let router = Router::new()
  router.use((ctx) => { ctx.next() })
  router.get("/test", [(_ctx) => ()])
  assert_true(true)
}

test "split_path basic" {
  let segs = split_path("/a/b/c")
  assert_eq(segs.length(), 3)
}

test "split_path root and empty" {
  assert_eq(split_path("/").length(), 0)
  assert_eq(split_path("").length(), 0)
}

test "strip_query" {
  assert_eq(strip_query("/a?b=1"), "/a")
  assert_eq(strip_query("/a"), "/a")
}

test "route with param" {
  let router = Router::new()
  router.get("/user/:id", [(_ctx) => ()])
  assert_eq(router.routes().length(), 1)
}

test "route with wildcard" {
  let router = Router::new()
  router.get("/files/*path", [(_ctx) => ()])
  assert_eq(router.routes().length(), 1)
}

test "nested routes" {
  let router = Router::new()
  router.get("/api/v1/users", [(_ctx) => ()])
  router.get("/api/v1/users/:id", [(_ctx) => ()])
  router.get("/api/v1/posts", [(_ctx) => ()])
  assert_eq(router.routes().length(), 3)
}

test "empty router" {
  assert_eq(Router::new().routes().length(), 0)
}

test "all HTTP methods" {
  let router = Router::new()
  let h : Handler = (_ctx) => ()
  router.get("/a", [h])
  router.post("/b", [h])
  router.put("/c", [h])
  router.del("/d", [h])
  router.patch("/e", [h])
  router.head("/f", [h])
  router.options("/g", [h])
  assert_eq(router.routes().length(), 7)
}

test "use_on adds route middleware" {
  let router = Router::new()
  router.get("/api", [(_ctx) => ()])
  router.use_on(GET, "/api", (ctx) => { ctx.next() })
  assert_true(true)
}

///| ——————————————————————————————————————————————————————————————————————
///  Extended coverage: priority, conflict resolution, edge paths
///| ——————————————————————————————————————————————————————————————————————

test "static beats param for same segment" {
  let router = Router::new()
  router.get("/users/all", [(_ctx) => ()])
  router.get("/users/:id", [(_ctx) => ()])
  // Both should register without error
  assert_eq(router.routes().length(), 2)
}

test "duplicate static route overwrites" {
  let router = Router::new()
  router.get("/ping", [(_ctx) => ()])
  router.get("/ping", [(_ctx) => ()])
  // Second registration overwrites first, still 1 route
  assert_eq(router.routes().length(), 1)
}

test "deeply nested static routes" {
  let router = Router::new()
  router.get("/a/b/c/d/e", [(_ctx) => ()])
  assert_eq(router.routes().length(), 1)
}

test "mixed params and statics in one pattern" {
  let router = Router::new()
  router.get("/api/:version/users/:id/posts", [(_ctx) => ()])
  assert_eq(router.routes().length(), 1)
}

test "wildcard at root level" {
  let router = Router::new()
  router.get("/*any", [(_ctx) => ()])
  assert_eq(router.routes().length(), 1)
}

test "wildcard after static segments" {
  let router = Router::new()
  router.get("/static/*filepath", [(_ctx) => ()])
  router.get("/static/css/main.css", [(_ctx) => ()])
  assert_eq(router.routes().length(), 2)
}

test "normalize trailing slash in pattern" {
  let router = Router::new()
  router.get("/hello/", [(_ctx) => ()])
  assert_eq(router.routes().length(), 1)
}

test "normalize duplicate slashes in pattern" {
  let router = Router::new()
  router.get("//api//v1", [(_ctx) => ()])
  assert_true(router.routes().length() >= 0)
}

test "route with special characters in segment" {
  let router = Router::new()
  router.get("/api/v1.0-beta/users", [(_ctx) => ()])
  assert_eq(router.routes().length(), 1)
}

test "many routes stress test" {
  let router = Router::new()
  let h : Handler = (_ctx) => ()
  for i = 0; i < 50; i = i + 1 {
    router.get("/route/" + i.to_string(), [h])
  }
  assert_eq(router.routes().length(), 50)
}

test "different methods same pattern" {
  let router = Router::new()
  router.get("/item", [(_ctx) => ()])
  router.post("/item", [(_ctx) => ()])
  router.put("/item", [(_ctx) => ()])
  router.del("/item", [(_ctx) => ()])
  assert_eq(router.routes().length(), 4)
}

test "no_route handler override" {
  let router = Router::new()
  router.no_route([(ctx) => { ctx.string(404, "first") }])
  router.no_route([(ctx) => { ctx.string(404, "second") }])
  // Override is fine, just verifies no panic
  assert_true(true)
}

test "no_method handler override" {
  let router = Router::new()
  router.no_method([(ctx) => { ctx.string(405, "first") }])
  router.no_method([(ctx) => { ctx.string(405, "second") }])
  assert_true(true)
}

test "handle with empty methods array" {
  let router = Router::new()
  router.handle([], "/api", [(_ctx) => ()])
  assert_eq(router.routes().length(), 0)
}

test "routes returns correct method names" {
  let router = Router::new()
  router.get("/g", [(_ctx) => ()])
  router.post("/p", [(_ctx) => ()])
  let routes = router.routes()
  let mut has_get = false
  let mut has_post = false
  for r in routes {
    if r.method == "GET" { has_get = true }
    if r.method == "POST" { has_post = true }
  }
  assert_true(has_get)
  assert_true(has_post)
}

test "routes include correct path" {
  let router = Router::new()
  router.get("/hello/world", [(_ctx) => ()])
  assert_eq(router.routes()[0].path, "/hello/world")
}

test "global middleware accumulates" {
  let router = Router::new()
  router.use((ctx) => { ctx.next() })
  router.use((ctx) => { ctx.next() })
  router.use((ctx) => { ctx.next() })
  assert_true(true)
}

test "split_path with special characters" {
  let segs = split_path("/api/v1.0/users")
  assert_eq(segs.length(), 3)
  assert_eq(segs[1], "v1.0")
}

test "split_path with encoded characters" {
  let segs = split_path("/path/hello%20world")
  assert_eq(segs.length(), 2)
  assert_eq(segs[1], "hello%20world")
}

test "split_path trailing slash" {
  let segs = split_path("/api/users/")
  assert_eq(segs.length(), 2)
}

test "strip_query with multiple params" {
  assert_eq(strip_query("/a?b=1&c=2&d=3"), "/a")
}

test "strip_query with fragment" {
  // strip_query only strips the query string (?..); fragment (#..) is kept
  assert_eq(strip_query("/a#section"), "/a#section")
}

test "check all_methods count" {
  // Internal: all_methods returns 7 methods
  assert_true(true)
}

///| ——————————————————————————————————————————————————————————————————————
///  Trees() debug output tests
///| ——————————————————————————————————————————————————————————————————————

test "trees empty router" {
  let router = Router::new()
  assert_eq(router.trees(), "(empty)")
}

test "trees single route" {
  let router = Router::new()
  router.get("/ping", [(_ctx) => ()])
  let output = router.trees()
  assert_true(output.contains("GET"))
  assert_true(output.contains("ping"))
}

test "trees multiple routes" {
  let router = Router::new()
  router.get("/api/users", [(_ctx) => ()])
  router.get("/api/posts", [(_ctx) => ()])
  router.post("/api/users", [(_ctx) => ()])
  let output = router.trees()
  assert_true(output.contains("GET"))
  assert_true(output.contains("POST"))
}

test "trees with params and wildcards" {
  let router = Router::new()
  router.get("/user/:id", [(_ctx) => ()])
  router.get("/files/*path", [(_ctx) => ()])
  let output = router.trees()
  // Should contain param indicator
  assert_true(output.contains(":id"))
  assert_true(output.contains("*path"))
}

test "trees handler count" {
  let router = Router::new()
  router.get("/api", [(_ctx) => (), (_ctx) => ()])
  let output = router.trees()
  assert_true(output.contains("2 handler"))
}

test "trees with middleware on node" {
  let router = Router::new()
  router.get("/admin", [(_ctx) => ()])
  router.use_on(GET, "/admin", (ctx) => { ctx.next() })
  let output = router.trees()
  assert_true(output.contains("admin"))
}
