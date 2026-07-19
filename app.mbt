///|
/// Mbit — convenience wrapper around Engine with a clean struct-based API.
///
/// ## Usage
///
/// ```
/// async fn main {
///   let a = Mbit::default()
///   a.get("/hello", [fn(ctx) { ctx.string(200, "Hi!") }])
///   a.use(logger())
///   a.run("0.0.0.0:8080")
/// }
/// ```

///|
/// Mbit wraps an Engine providing method-based access.
pub struct Mbit {
  engine : Engine
}

///|
/// Create an Mbit with a custom engine.
pub fn Mbit::new(engine : Engine) -> Mbit {
  { engine, }
}

///|
/// Create an Mbit with default settings (logger + recovery middleware).
pub fn Mbit::default() -> Mbit {
  { engine: default() }
}

///|
/// Expose the underlying Engine for advanced usage.
pub fn Mbit::engine(self : Mbit) -> Engine {
  self.engine
}

///| ——————————————————————————————————————————————————————————————————————
///  Route registration
///| ——————————————————————————————————————————————————————————————————————

pub fn Mbit::get(self : Mbit, pattern : String, handlers : Array[Handler]) -> Unit {
  self.engine.get(pattern, handlers) |> ignore
}
pub fn Mbit::post(self : Mbit, pattern : String, handlers : Array[Handler]) -> Unit {
  self.engine.post(pattern, handlers) |> ignore
}
pub fn Mbit::put(self : Mbit, pattern : String, handlers : Array[Handler]) -> Unit {
  self.engine.put(pattern, handlers) |> ignore
}
pub fn Mbit::delete(self : Mbit, pattern : String, handlers : Array[Handler]) -> Unit {
  self.engine.del(pattern, handlers) |> ignore
}
pub fn Mbit::patch(self : Mbit, pattern : String, handlers : Array[Handler]) -> Unit {
  self.engine.patch(pattern, handlers) |> ignore
}
pub fn Mbit::head(self : Mbit, pattern : String, handlers : Array[Handler]) -> Unit {
  self.engine.head(pattern, handlers) |> ignore
}
pub fn Mbit::options(self : Mbit, pattern : String, handlers : Array[Handler]) -> Unit {
  self.engine.options(pattern, handlers) |> ignore
}
pub fn Mbit::any(self : Mbit, pattern : String, handlers : Array[Handler]) -> Unit {
  self.engine.any(pattern, handlers) |> ignore
}
pub fn Mbit::handle(
  self : Mbit,
  methods : Array[Method],
  pattern : String,
  handlers : Array[Handler],
) -> Unit {
  self.engine.handle(methods, pattern, handlers) |> ignore
}

///| ——————————————————————————————————————————————————————————————————————
///  Middleware & error handlers
///| ——————————————————————————————————————————————————————————————————————

pub fn Mbit::use(self : Mbit, mw : Handler) -> Unit {
  self.engine.use(mw) |> ignore
}
pub fn Mbit::no_route(self : Mbit, handlers : Array[Handler]) -> Unit {
  self.engine.no_route(handlers)
}
pub fn Mbit::no_method(self : Mbit, handlers : Array[Handler]) -> Unit {
  self.engine.no_method(handlers)
}

///| ——————————————————————————————————————————————————————————————————————
///  Route group
///| ——————————————————————————————————————————————————————————————————————

pub fn Mbit::group(self : Mbit, prefix : String) -> Group {
  self.engine.group(prefix)
}

///| ——————————————————————————————————————————————————————————————————————
///  Static files
///| ——————————————————————————————————————————————————————————————————————

pub fn Mbit::static_file(self : Mbit, relative_path : String, file_path : String) -> Unit {
  self.engine.static_file(relative_path, file_path)
}
pub fn Mbit::static_(self : Mbit, relative_path : String, root : String) -> Unit {
  self.engine.static_files_engine(relative_path, root)
}
pub fn Mbit::static_fs(self : Mbit, relative_path : String, root : String) -> Unit {
  self.engine.static_fs(relative_path, root)
}

///| ——————————————————————————————————————————————————————————————————————
///  Templates
///| ——————————————————————————————————————————————————————————————————————

pub fn Mbit::set_html_template(self : Mbit, name : String, content : String) -> Unit {
  self.engine.set_html_template(name, content)
}
pub fn Mbit::set_template_delims(self : Mbit, left : String, right : String) -> Unit {
  self.engine.set_template_delims(left, right)
}
pub fn Mbit::set_func_map(self : Mbit, funcs : Map[String, String]) -> Unit {
  self.engine.set_func_map(funcs)
}

///| ——————————————————————————————————————————————————————————————————————
///  Configuration
///| ——————————————————————————————————————————————————————————————————————

pub fn Mbit::max_multipart_memory(self : Mbit, bytes : Int64) -> Unit {
  self.engine.set_max_multipart_memory(bytes)
}
pub fn Mbit::redirect_trailing_slash(self : Mbit, enable : Bool) -> Unit {
  self.engine.redirect_trailing_slash(enable)
}
pub fn Mbit::handle_method_not_allowed(self : Mbit, enable : Bool) -> Unit {
  self.engine.handle_method_not_allowed(enable)
}
pub fn Mbit::redirect_fixed_path(self : Mbit, enable : Bool) -> Unit {
  self.engine.redirect_fixed_path(enable)
}
pub fn Mbit::remove_extra_slash(self : Mbit, enable : Bool) -> Unit {
  self.engine.remove_extra_slash(enable)
}

///| ——————————————————————————————————————————————————————————————————————
///  Server
///| ——————————————————————————————————————————————————————————————————————

pub async fn Mbit::run(self : Mbit, addr : String) -> Unit {
  self.engine.run(addr)
}
pub async fn Mbit::run_default(self : Mbit) -> Unit {
  self.engine.run_default()
}
pub async fn Mbit::run_with_shutdown(
  self : Mbit,
  addr : String,
  on_shutdown~ : () -> Unit = fn() {},
) -> Unit {
  self.engine.run_with_shutdown(addr, on_shutdown=on_shutdown)
}
pub fn Mbit::shutdown(self : Mbit, cleanup~ : () -> Unit = fn() {}) -> Bool {
  self.engine.shutdown(cleanup=cleanup)
}

///| ——————————————————————————————————————————————————————————————————————
///  Debug
///| ——————————————————————————————————————————————————————————————————————

pub fn Mbit::routes(self : Mbit) -> Array[RouteInfo] {
  self.engine.routes()
}
pub fn Mbit::trees(self : Mbit) -> String {
  self.engine.router.trees()
}
