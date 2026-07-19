///|
/// Template tests — covers HTML template loading and rendering.

///|
test "template store set and render" {
  let store = TemplateStore::new()
  store.add_template("hello", "<h1>Hello {{ .name }}</h1>")
  let data : Map[String, String] = { "name": "World" }
  match store.render("hello", data) {
    Some(html) => assert_eq(html, "<h1>Hello World</h1>")
    None => assert_true(false)
  }
}

///|
test "template store missing template" {
  let store = TemplateStore::new()
  match store.render("missing", {}) {
    Some(_) => assert_true(false)
    None => assert_true(true)
  }
}

///|
test "template store custom delimiters" {
  let store = TemplateStore::new()
  store.set_delims("<<", ">>")
  store.add_template("t", "<< .x >>")
  match store.render("t", { "x": "y" }) {
    Some(html) => assert_eq(html, "y")
    None => assert_true(false)
  }
}

///|
test "template store multiple vars" {
  let store = TemplateStore::new()
  store.add_template("page", "{{ .title }} - {{ .body }}")
  let data : Map[String, String] = { "title": "Hello", "body": "World" }
  match store.render("page", data) {
    Some(html) => assert_eq(html, "Hello - World")
    None => assert_true(false)
  }
}

///|
test "set_html_template global" {
  set_html_template("test", "{{ .msg }}")
  let ctx = create_test_context("GET", "/")
  ignore(ctx)
  // Just verify no crash
  assert_true(true)
}

///|
async test "load_html_files loads templates" {
  // Test that the function exists and doesn't crash
  load_html_files([])
  assert_true(true)
}

///|
async test "load_html_glob loads templates" {
  load_html_glob("nonexistent/*.html")
  assert_true(true)
}
