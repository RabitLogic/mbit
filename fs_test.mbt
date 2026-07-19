///|
/// File serving tests — static_files, dir_listing, guess_content_type.

test "guess_content_type html" {
  assert_eq(guess_content_type("page.html"), "text/html; charset=utf-8")
}

test "guess_content_type css" {
  assert_eq(guess_content_type("style.css"), "text/css; charset=utf-8")
}

test "guess_content_type js" {
  assert_eq(guess_content_type("app.js"), "application/javascript; charset=utf-8")
}

test "guess_content_type json" {
  assert_eq(guess_content_type("data.json"), "application/json; charset=utf-8")
}

test "guess_content_type png" {
  assert_eq(guess_content_type("img.png"), "image/png")
}

test "guess_content_type jpg" {
  assert_eq(guess_content_type("photo.jpg"), "image/jpeg")
  assert_eq(guess_content_type("photo.jpeg"), "image/jpeg")
}

test "guess_content_type pdf" {
  assert_eq(guess_content_type("doc.pdf"), "application/pdf")
}

test "guess_content_type unknown" {
  assert_eq(guess_content_type("file.xyz"), "application/octet-stream")
}

test "guess_content_type no extension" {
  assert_eq(guess_content_type("noext"), "application/octet-stream")
}

async test "dir_listing returns HTML" {
  let html = dir_listing("./nonexistent_dir")
  assert_true(html.has_prefix("<html>"))
}

async test "dir_listing contains title" {
  let html = dir_listing("/tmp")
  assert_true(html.contains("Directory"))
}

test "static_files returns Handler" {
  let h = static_files("/static", "./public")
  // Verify it's callable (type check)
  ignore(h)
  assert_true(true)
}
