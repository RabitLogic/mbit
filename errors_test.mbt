///|
/// Errors tests — Method enum, status_text, Error enum.

test "Method from_native GET" {
  assert_eq(Method::from_native(Get), GET)
}

test "Method from_native POST" {
  assert_eq(Method::from_native(Post), POST)
}

test "Method to_native GET" {
  let m : Method = GET
  assert_eq(m.to_native(), Get)
}

test "Method to_string" {
  let ms : Array[Method] = [GET, POST, PUT, DELETE, PATCH, HEAD, OPTIONS]
  assert_eq(ms[0].to_string(), "GET")
  assert_eq(ms[1].to_string(), "POST")
  assert_eq(ms[2].to_string(), "PUT")
  assert_eq(ms[3].to_string(), "DELETE")
  assert_eq(ms[4].to_string(), "PATCH")
  assert_eq(ms[5].to_string(), "HEAD")
  assert_eq(ms[6].to_string(), "OPTIONS")
}

test "status_text 200" { assert_eq(status_text(200), "OK") }
test "status_text 201" { assert_eq(status_text(201), "Created") }
test "status_text 204" { assert_eq(status_text(204), "No Content") }
test "status_text 301" { assert_eq(status_text(301), "Moved Permanently") }
test "status_text 400" { assert_eq(status_text(400), "Bad Request") }
test "status_text 401" { assert_eq(status_text(401), "Unauthorized") }
test "status_text 403" { assert_eq(status_text(403), "Forbidden") }
test "status_text 404" { assert_eq(status_text(404), "Not Found") }
test "status_text 405" { assert_eq(status_text(405), "Method Not Allowed") }
test "status_text 413" { assert_eq(status_text(413), "Payload Too Large") }
test "status_text 429" { assert_eq(status_text(429), "Too Many Requests") }
test "status_text 500" { assert_eq(status_text(500), "Internal Server Error") }
test "status_text unknown" { assert_eq(status_text(999), "Unknown") }

test "Method Show derivation" {
  let m : Method = GET
  assert_eq(m.to_string(), "GET")
}
