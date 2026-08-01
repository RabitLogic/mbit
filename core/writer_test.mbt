///|
/// ResponseWriter tests — write, flush, size tracking, status.

test "new ResponseWriter has default status 200" {
  let w = ResponseWriter::new(ResponseConn::Test(TestConn::new()))
  assert_eq(w.status(), 200)
  assert_false(w.written())
  assert_eq(w.size(), 0)
}

async test "write_header changes status" {
  let w = ResponseWriter::new(ResponseConn::Test(TestConn::new()))
  w.write_header(404)
  assert_eq(w.status(), 404)
  assert_true(w.written())
}

async test "write increments size" {
  let w = ResponseWriter::new(ResponseConn::Test(TestConn::new()))
  w.write("hello")
  assert_eq(w.size(), 5)
}

async test "write_string same as write" {
  let w = ResponseWriter::new(ResponseConn::Test(TestConn::new()))
  w.write_string("test")
  assert_eq(w.size(), 4)
}

async test "multiple writes accumulate size" {
  let w = ResponseWriter::new(ResponseConn::Test(TestConn::new()))
  w.write("abc")
  w.write("def")
  assert_eq(w.size(), 6)
}

async test "write_header_now forces header" {
  let w = ResponseWriter::new(ResponseConn::Test(TestConn::new()))
  assert_false(w.written())
  w.write_header_now()
  assert_true(w.written())
}

async test "flush does not crash" {
  let w = ResponseWriter::new(ResponseConn::Test(TestConn::new()))
  w.flush()
  assert_true(true)
}

async test "end does not crash" {
  let w = ResponseWriter::new(ResponseConn::Test(TestConn::new()))
  w.end()
  assert_true(true)
}
