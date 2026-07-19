///|
/// Recovery middleware — catches panics/exceptions in handlers and returns 500.
///
/// See `recovery.go` equivalent.
///
/// Usage:
/// ```
/// app.use(recovery())
/// ```

pub fn recovery() -> Handler {
  fn(ctx) {
    try {
      ctx.next()
    } catch {
      _ =>
        if !ctx.is_written() {
          let body : Json = Json::object({
            "error": Json::string("Internal Server Error"),
            "code": Json::number(500.0),
          })
          ctx.json(500, body)
        }
    }
  }
}
