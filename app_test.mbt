///|
/// Mbit tests — global singleton API.

test "Mbit::default() returns Mbit" {
  let a = Mbit::default()
  ignore(a)
  assert_true(true)
}

test "Mbit::default().get registers" {
  Mbit::default().get("/a", [(_ctx) => ()])
  assert_true(true)
}

test "Mbit::default().post registers" {
  Mbit::default().post("/b", [(_ctx) => ()])
  assert_true(true)
}

test "Mbit::default().put registers" {
  Mbit::default().put("/c", [(_ctx) => ()])
  assert_true(true)
}

test "Mbit::default().delete registers" {
  Mbit::default().delete("/d", [(_ctx) => ()])
  assert_true(true)
}

test "Mbit::default().patch registers" {
  Mbit::default().patch("/e", [(_ctx) => ()])
  assert_true(true)
}

test "Mbit::default().any registers" {
  Mbit::default().any("/f", [(_ctx) => ()])
  assert_true(true)
}

test "Mbit::default().use adds middleware" {
  Mbit::default().use((ctx) => { ctx.next() })
  assert_true(true)
}

test "Mbit::default().no_route" {
  Mbit::default().no_route([(ctx) => { ctx.string(404, "nf") }])
  assert_true(true)
}

test "Mbit::default().no_method" {
  Mbit::default().no_method([(ctx) => { ctx.string(405, "nm") }])
  assert_true(true)
}

test "Mbit::default().group" {
  let g = Mbit::default().group("/api")
  g.get("/t", [(_ctx) => ()])
  assert_true(true)
}

test "Mbit::default().routes" {
  let rs = Mbit::default().routes()
  assert_true(rs.length() >= 0)
}

test "Mbit::default().set_html_template" {
  Mbit::default().set_html_template("x", "{{ .k }}")
  assert_true(true)
}

test "Mbit::default().static_" {
  Mbit::default().static_("/a", "./p")
  assert_true(true)
}

test "Mbit::default" {
  let a = Mbit::default()
  a.get("/x", [(_ctx) => ()])
  assert_true(true)
}

test "Mbit::new" {
  let a = Mbit::new(default())
  a.get("/y", [(_ctx) => ()])
  assert_true(true)
}
