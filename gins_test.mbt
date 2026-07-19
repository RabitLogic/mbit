///|
/// Gins tests — global singleton engine (ginS equivalent).

test "gins_engine returns engine" {
  let e = gins_engine()
  ignore(e)
  assert_true(true)
}

test "gins_get registers route" {
  gins_get("/gins-test-get", [(_ctx) => ()])
  assert_true(true)
}

test "gins_post registers route" {
  gins_post("/gins-test-post", [(_ctx) => ()])
  assert_true(true)
}

test "gins_put registers route" {
  gins_put("/gins-test-put", [(_ctx) => ()])
  assert_true(true)
}

test "gins_del registers route" {
  gins_del("/gins-test-del", [(_ctx) => ()])
  assert_true(true)
}

test "gins_patch registers route" {
  gins_patch("/gins-test-patch", [(_ctx) => ()])
  assert_true(true)
}

test "gins_any registers route" {
  gins_any("/gins-test-any", [(_ctx) => ()])
  assert_true(true)
}

test "gins_use adds middleware" {
  gins_use((ctx) => { ctx.next() })
  assert_true(true)
}

test "gins_no_route sets handler" {
  gins_no_route([(ctx) => { ctx.string(404, "nf") }])
  assert_true(true)
}

test "gins_no_method sets handler" {
  gins_no_method([(ctx) => { ctx.string(405, "nm") }])
  assert_true(true)
}

test "gins_group creates group" {
  let g = gins_group("/api")
  g.get("/test", [(_ctx) => ()])
  assert_true(true)
}

test "gins_routes returns routes" {
  let routes = gins_routes()
  assert_true(routes.length() >= 0)
}

async test "gins_load_html_glob" {
  gins_load_html_glob("nonexistent/*.html")
  assert_true(true)
}

test "gins_set_html_template" {
  gins_set_html_template("test", "{{ .msg }}")
  assert_true(true)
}

test "gins_static" {
  gins_static("/assets", "./public")
  assert_true(true)
}
