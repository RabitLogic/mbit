///|
/// Global singleton engine — convenience functions for simple apps.
///
/// Global singleton engine for quick prototyping.
/// Use for quick prototyping without creating an Engine manually.
///
/// ```
/// async fn main {
///   gins_get("/hello", [fn(ctx) { ctx.string(200, "hi") }])
///   gins_run("0.0.0.0:8080")
/// }
/// ```

///|
/// Global default engine instance.
let global_engine : Engine = default()

///|
/// Get the global engine instance.
pub fn gins_engine() -> Engine {
  global_engine
}

///|
/// GET route on the global engine.
pub fn gins_get(pattern : String, handlers : Array[Handler]) -> Unit {
  global_engine.get(pattern, handlers) |> ignore
}

///|
/// POST route on the global engine.
pub fn gins_post(pattern : String, handlers : Array[Handler]) -> Unit {
  global_engine.post(pattern, handlers) |> ignore
}

///|
/// PUT route on the global engine.
pub fn gins_put(pattern : String, handlers : Array[Handler]) -> Unit {
  global_engine.put(pattern, handlers) |> ignore
}

///|
/// DELETE route on the global engine.
pub fn gins_del(pattern : String, handlers : Array[Handler]) -> Unit {
  global_engine.del(pattern, handlers) |> ignore
}

///|
/// PATCH route on the global engine.
pub fn gins_patch(pattern : String, handlers : Array[Handler]) -> Unit {
  global_engine.patch(pattern, handlers) |> ignore
}

///|
/// Any-method route on the global engine.
pub fn gins_any(pattern : String, handlers : Array[Handler]) -> Unit {
  global_engine.any(pattern, handlers) |> ignore
}

///|
/// Add global middleware.
pub fn gins_use(mw : Handler) -> Unit {
  global_engine.use(mw) |> ignore
}

///|
/// Set custom 404 handler on the global engine.
pub fn gins_no_route(handlers : Array[Handler]) -> Unit {
  global_engine.no_route(handlers)
}

///|
/// Set custom 405 handler on the global engine.
pub fn gins_no_method(handlers : Array[Handler]) -> Unit {
  global_engine.no_method(handlers)
}

///|
/// Create a route group on the global engine.
pub fn gins_group(prefix : String) -> Group {
  global_engine.group(prefix)
}

///|
/// Run the global engine on the given address.
pub async fn gins_run(addr : String) -> Unit {
  global_engine.run(addr)
}

///|
/// Run the global engine on the default port 8080.
pub async fn gins_run_default() -> Unit {
  global_engine.run_default()
}

///|
/// List routes on the global engine.
pub fn gins_routes() -> Array[RouteInfo] {
  global_engine.routes()
}

///|
/// Load HTML templates on the global engine.
pub async fn gins_load_html_glob(pattern : String) -> Unit {
  global_engine.load_html_glob(pattern)
}

///|
/// Set HTML template on the global engine.
pub fn gins_set_html_template(name : String, content : String) -> Unit {
  global_engine.set_html_template(name, content)
}

///|
/// Serve static files on the global engine.
pub fn gins_static(relative_path : String, root : String) -> Unit {
  global_engine.static_files_engine(relative_path, root)
}
