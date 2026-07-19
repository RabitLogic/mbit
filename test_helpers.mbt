///|
/// Test helpers — utilities for creating test contexts.
///
/// See `CreateTestContext()` equivalent.

///|
/// CreateTestContext returns a Context suitable for testing.
/// Uses a minimal dummy HTTP request and an in-memory test connection.
///
/// ```
/// let ctx = create_test_context("GET", "/test")
/// assert_eq(ctx.method(), "GET")
/// ```
pub fn create_test_context(meth : String, path : String) -> Context {
  let native_method : @http.RequestMethod = match meth {
    "GET" => Get
    "POST" => Post
    "PUT" => Put
    "DELETE" => Delete
    "PATCH" => Patch
    "HEAD" => Head
    "OPTIONS" => Options
    _ => Get
  }
  let req : @http.Request = { meth: native_method, path, headers: Map([]) }
  let conn = ResponseConn::Test(TestConn::new())
  let (reader, writer) = @io.pipe()
  writer.close()
  let ctx = Context::new(req, reader, conn, [])
  // Pre-fill the body cache so tests never block reading the dummy pipe.
  ctx.body = Some("")
  ctx
}

///|
/// Get a test context with pre-set handlers for chain testing.
pub fn create_test_context_with_handlers(
  meth : String,
  path : String,
  handlers : Array[Handler],
) -> Context {
  let ctx = create_test_context(meth, path)
  ctx.handlers = handlers
  ctx
}
