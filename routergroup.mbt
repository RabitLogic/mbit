///|
/// Route groups — prefix-based grouping with shared middleware.
///
/// Groups allow you to organize routes under a common path prefix
/// and apply middleware to all routes within the group.
///
/// ## Example
///
/// ```
/// let api = app.group("/api")
/// api.use(auth_middleware)
/// api.get("/users", [list_users])
/// api.post("/users", [create_user])
/// // Registers: GET /api/users, POST /api/users (both with auth middleware)
/// ```

///|
/// A route group shares a path prefix and middleware.
pub(all) struct Group {
  router : Router
  prefix : String
  /// Middleware applied to all routes in this group
  middlewares : Array[Handler]
}

///|
/// Create a new route group.
pub fn Group::new(
  router : Router,
  prefix : String,
) -> Group {
  { router, prefix, middlewares: [] }
}

///|
/// Add middleware to this group. Middleware is applied to all routes
/// registered through this group, in the order added.
/// Returns the group for method chaining.
pub fn Group::use(self : Group, mw : Handler) -> Group {
  self.middlewares.push(mw)
  self
}

///|
/// Return the middleware handlers attached to this group.
/// See `group.Handlers` equivalent.
pub fn Group::handlers(self : Group) -> Array[Handler] {
  self.middlewares
}

///|
/// Normalize a pattern by joining the group prefix with the route pattern.
fn Group::full_path(self : Group, pattern : String) -> String {
  if self.prefix == "" || self.prefix == "/" {
    return pattern
  }
  if pattern == "/" {
    return self.prefix
  }
  if pattern.has_prefix("/") {
    return self.prefix + pattern
  }
  return self.prefix + "/" + pattern
}

///|
/// Build the full handler chain: group middleware + route handlers.
fn Group::build_chain(self : Group, handlers : Array[Handler]) -> Array[Handler] {
  let chain : Array[Handler] = []
  for mw in self.middlewares {
    chain.push(mw)
  }
  for h in handlers {
    chain.push(h)
  }
  chain
}

///|
/// Register a GET route under this group.
pub fn Group::get(
  self : Group,
  pattern : String,
  handlers : Array[Handler],
) -> Unit {
  self.router.get(self.full_path(pattern), self.build_chain(handlers))
}

///|
/// Register a POST route under this group.
pub fn Group::post(
  self : Group,
  pattern : String,
  handlers : Array[Handler],
) -> Unit {
  self.router.post(self.full_path(pattern), self.build_chain(handlers))
}

///|
/// Register a PUT route under this group.
pub fn Group::put(
  self : Group,
  pattern : String,
  handlers : Array[Handler],
) -> Unit {
  self.router.put(self.full_path(pattern), self.build_chain(handlers))
}

///|
/// Register a DELETE route under this group.
pub fn Group::del(
  self : Group,
  pattern : String,
  handlers : Array[Handler],
) -> Unit {
  self.router.del(self.full_path(pattern), self.build_chain(handlers))
}

///|
/// Register a PATCH route under this group.
pub fn Group::patch(
  self : Group,
  pattern : String,
  handlers : Array[Handler],
) -> Unit {
  self.router.patch(self.full_path(pattern), self.build_chain(handlers))
}

///|
/// Register a HEAD route under this group.
pub fn Group::head(
  self : Group,
  pattern : String,
  handlers : Array[Handler],
) -> Unit {
  self.router.head(self.full_path(pattern), self.build_chain(handlers))
}

///|
/// Register an OPTIONS route under this group.
pub fn Group::options(
  self : Group,
  pattern : String,
  handlers : Array[Handler],
) -> Unit {
  self.router.options(self.full_path(pattern), self.build_chain(handlers))
}

///|
/// Handle multiple HTTP methods for the same pattern under this group.
pub fn Group::handle(
  self : Group,
  methods : Array[Method],
  pattern : String,
  handlers : Array[Handler],
) -> Unit {
  self.router.handle(methods, self.full_path(pattern), self.build_chain(handlers))
}

///|
/// Register a route that matches ANY HTTP method under this group.
///
/// ```
/// group.any("/health", [health_check])
/// ```
pub fn Group::any(
  self : Group,
  pattern : String,
  handlers : Array[Handler],
) -> Unit {
  self.router.any(self.full_path(pattern), self.build_chain(handlers))
}

///|
/// Create a nested group under this group.
/// The nested group inherits this group's prefix and middleware.
pub fn Group::group(self : Group, prefix : String) -> Group {
  let nested = Group::new(self.router, self.full_path(prefix))
  // Inherit parent middleware
  for mw in self.middlewares {
    nested.middlewares.push(mw)
  }
  nested
}

///|
/// Return the base path of this group.
///
/// ```
/// let api = app.group("/api/v1")
/// println(api.base_path())  // "/api/v1"
/// ```
pub fn Group::base_path(self : Group) -> String {
  self.prefix
}

///|
/// Serve static files from a directory under this group's prefix.
///
/// ```
/// let assets = app.group("/assets")
/// assets.static("/css", "./public/css")
/// ```
pub fn Group::static_files(
  self : Group,
  relative_path : String,
  root : String,
) -> Unit {
  let prefix = self.full_path(relative_path)
  self.router.get(
    prefix + "/*filepath",
    self.build_chain([
      async fn(ctx) {
        let file = ctx.param_default("filepath", "")
        let file_path = root + "/" + file
        try {
          let content = @fs.read_file(file_path).text()
          let ct = guess_content_type(file_path)
          ctx.data(200, ct, content)
        } catch {
          _ => ctx.abort_with_status(404, "File not found")
        }
      },
    ]),
  )
}

///|
/// Serve a single static file under this group's prefix.
///
/// ```
/// let assets = app.group("/assets")
/// assets.static_file("/favicon.ico", "./public/favicon.ico")
/// ```
pub fn Group::static_file(
  self : Group,
  relative_path : String,
  file_path : String,
) -> Unit {
  self.router.get(
    self.full_path(relative_path),
    self.build_chain([
      async fn(ctx) {
        try {
          let content = @fs.read_file(file_path).text()
          let ct = guess_content_type(file_path)
          ctx.data(200, ct, content)
        } catch {
          _ => ctx.abort_with_status(404, "File not found")
        }
      },
    ]),
  )
}

///|
/// Serve static files from a file system under this group's prefix.
/// See `group.StaticFS()` equivalent.
///
/// ```
/// let assets = app.group("/assets")
/// assets.static_fs("/css", "./public/css")
/// ```
pub fn Group::static_fs(
  self : Group,
  relative_path : String,
  root : String,
) -> Unit {
  self.static_files(relative_path, root)
}
