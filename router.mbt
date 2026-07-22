///|
/// Trie-based HTTP router — the core of mbit's routing engine.
///
/// ## Design
///
/// Routes are stored in a segment trie. Each URL segment becomes a tree node.
/// Three node kinds exist:
/// - **Static**: exact string match (e.g., `article`)
/// - **Param**: single-segment wildcard `:name` (e.g., `:id`)
/// - **Wildcard**: multi-segment wildcard `*path` (e.g., `*filepath`)
///
/// Each HTTP method has its own root trie, so method-specific handlers
/// are stored directly as `Array[Handler]` at the leaf node.
///
/// ## Matching priority
///
/// For a given path segment, matching tries in this order:
/// 1. Static (exact match)
/// 2. Param (`:name`)
/// 3. Wildcard (`*path`)
///
/// This mirrors most-specific match wins: most-specific match wins.

///|
/// A node in the route trie.
pub(all) struct Node {
  /// The path segment this node represents
  seg : String
  /// Kind of this node
  kind : NodeKind
  /// Static children, keyed by segment string
  children : Map[String, Node]
  /// A single `:param` child (only one allowed per node)
  mut param_child : Node?
  /// A single `*wildcard` child (only one allowed per node)
  mut wildcard_child : Node?
  /// Handler chain for the route at this node (method-specific trie)
  mut handlers : Array[Handler]
  /// Middleware scoped to this subtree
  middlewares : Array[Handler]
}

///|
enum NodeKind {
  Root // The root node (matches nothing)
  Static // Exact string match
  Param // :param_name
  Wildcard // *wildcard_name
}

///|
fn Node::new(seg : String, kind : NodeKind) -> Node {
  {
    seg,
    kind,
    children: Map([]),
    param_child: None,
    wildcard_child: None,
    handlers: [],
    middlewares: [],
  }
}

///|
/// The Router stores all routes in a trie and dispatches incoming requests.
pub(all) struct Router {
  roots : Map[Method, Node]
  mut global_middleware : Array[Handler]
  mut no_route_handlers : Array[Handler]
  mut no_method_handlers : Array[Handler]
}

///|
/// Create a new empty Router.
pub fn Router::new() -> Router {
  let roots : Map[Method, Node] = Map([])
  for meth in all_methods() {
    roots.set(meth, Node::new("/", Root))
  }
  { roots, global_middleware: [], no_route_handlers: [], no_method_handlers: [] }
}

///|
/// All supported HTTP methods.
fn all_methods() -> Array[Method] {
  [GET, POST, PUT, DELETE, PATCH, HEAD, OPTIONS]
}

///|
/// Add global middleware (applied to every route).
pub fn Router::use(self : Router, handler : Handler) -> Unit {
  self.global_middleware.push(handler)
}

///|
/// Add middleware to a specific route pattern (applies to that subtree).
pub fn Router::use_on(
  self : Router,
  meth : Method,
  pattern : String,
  handler : Handler,
) -> Unit {
  let root = match self.roots.get(meth) {
    Some(n) => n
    None => return
  }
  let segments = parse_segments(pattern)
  add_middleware_to_node(root, segments, 0, handler)
}

///|
fn add_middleware_to_node(
  node : Node,
  segments : Array[(String, NodeKind)],
  idx : Int,
  handler : Handler,
) -> Unit {
  if idx >= segments.length() {
    node.middlewares.push(handler)
    return
  }
  let (seg, kind) = segments[idx]
  match kind {
    Static =>
      match node.children.get(seg) {
        Some(child) => add_middleware_to_node(child, segments, idx + 1, handler)
        None => ()
      }
    Param =>
      match node.param_child {
        Some(child) => add_middleware_to_node(child, segments, idx + 1, handler)
        None => ()
      }
    Wildcard =>
      match node.wildcard_child {
        Some(child) => child.middlewares.push(handler)
        None => ()
      }
    Root => add_middleware_to_node(node, segments, idx + 1, handler)
  }
}

///| ——————————————————————————————————————————————————————————————————————
///  Custom error handlers
///| ——————————————————————————————————————————————————————————————————————

///|
/// Set a custom 404 handler. Called when no route matches the request path.
pub fn Router::no_route(self : Router, handlers : Array[Handler]) -> Unit {
  self.no_route_handlers = handlers
}

///|
/// Set a custom 405 handler. Called when a path matches but the HTTP method
/// is not allowed.
pub fn Router::no_method(self : Router, handlers : Array[Handler]) -> Unit {
  self.no_method_handlers = handlers
}

///|
/// Register a GET route with one or more handlers.
/// The last handler is typically the "real" handler; preceding ones are middleware.
pub fn Router::get(
  self : Router,
  pattern : String,
  handlers : Array[Handler],
) -> Unit {
  self.add_route(GET, pattern, handlers)
}

///|
/// Register a POST route.
pub fn Router::post(
  self : Router,
  pattern : String,
  handlers : Array[Handler],
) -> Unit {
  self.add_route(POST, pattern, handlers)
}

///|
/// Register a PUT route.
pub fn Router::put(
  self : Router,
  pattern : String,
  handlers : Array[Handler],
) -> Unit {
  self.add_route(PUT, pattern, handlers)
}

///|
/// Register a DELETE route.
pub fn Router::del(
  self : Router,
  pattern : String,
  handlers : Array[Handler],
) -> Unit {
  self.add_route(DELETE, pattern, handlers)
}

///|
/// Register a PATCH route.
pub fn Router::patch(
  self : Router,
  pattern : String,
  handlers : Array[Handler],
) -> Unit {
  self.add_route(PATCH, pattern, handlers)
}

///|
/// Register a HEAD route.
pub fn Router::head(
  self : Router,
  pattern : String,
  handlers : Array[Handler],
) -> Unit {
  self.add_route(HEAD, pattern, handlers)
}

///|
/// Register an OPTIONS route.
pub fn Router::options(
  self : Router,
  pattern : String,
  handlers : Array[Handler],
) -> Unit {
  self.add_route(OPTIONS, pattern, handlers)
}

///|
/// Register a route that matches ANY HTTP method.
///
/// ```
/// router.any("/api/health", [health_check])
/// ```
pub fn Router::any(
  self : Router,
  pattern : String,
  handlers : Array[Handler],
) -> Unit {
  for meth in all_methods() {
    self.add_route(meth, pattern, handlers)
  }
}

///|
/// Handle multiple HTTP methods for the same pattern.
pub fn Router::handle(
  self : Router,
  methods : Array[Method],
  pattern : String,
  handlers : Array[Handler],
) -> Unit {
  for meth in methods {
    self.add_route(meth, pattern, handlers)
  }
}

///|
/// Internal: insert a route into the trie.
fn Router::add_route(
  self : Router,
  meth : Method,
  pattern : String,
  handlers : Array[Handler],
) -> Unit {
  // Normalize path
  let normalized = clean_path(pattern)
  debug_print_route(meth.to_string(), normalized)
  let root = match self.roots.get(meth) {
    Some(n) => n
    None => {
      let n = Node::new("/", Root)
      self.roots.set(meth, n)
      n
    }
  }
  let segments = parse_segments(normalized)
  insert_node(root, segments, 0, handlers)
}

///|
/// Parse a route pattern into segment descriptors.
fn parse_segments(pattern : String) -> Array[(String, NodeKind)] {
  let parts = pattern.split("/")
  let segs : Array[(String, NodeKind)] = []
  for part in parts {
    if part == "" {
      continue
    }
    if part.has_prefix("*") {
      segs.push((part[1:].to_owned(), Wildcard))
    } else if part.has_prefix(":") {
      segs.push((part[1:].to_owned(), Param))
    } else {
      segs.push((part.to_owned(), Static))
    }
  }
  segs
}

///|
/// Recursively insert a route into the trie.
fn insert_node(
  node : Node,
  segments : Array[(String, NodeKind)],
  idx : Int,
  handlers : Array[Handler],
) -> Unit {
  if idx >= segments.length() {
    // Leaf node — store handlers for the route
    node.handlers = handlers
    return
  }
  let (seg, kind) = segments[idx]
  match kind {
    Static => {
      let child = match node.children.get(seg) {
        Some(c) => c
        None => {
          let c = Node::new(seg, Static)
          node.children.set(seg, c)
          c
        }
      }
      insert_node(child, segments, idx + 1, handlers)
    }
    Param => {
      let child = match node.param_child {
        Some(c) => c
        None => {
          let c = Node::new(seg, Param)
          node.param_child = Some(c)
          c
        }
      }
      insert_node(child, segments, idx + 1, handlers)
    }
    Wildcard => {
      let child = match node.wildcard_child {
        Some(c) => c
        None => {
          let c = Node::new(seg, Wildcard)
          node.wildcard_child = Some(c)
          c
        }
      }
      // Wildcard is always the last segment; store handlers here
      child.handlers = handlers
      // No need to recurse further for wildcard
    }
    Root =>
      // Root node — continue to next segment
      insert_node(node, segments, idx + 1, handlers)
  }
}

///| ——————————————————————————————————————————————————————————————————————
///  Dispatch
///| ——————————————————————————————————————————————————————————————————————

///|
/// Result of route matching.
pub(all) struct MatchResult {
  handlers : Array[Handler]
  params : Map[String, String]
  node_middlewares : Array[Handler]
}

///|
/// Dispatch an incoming native HTTP request through the router.
/// Returns `true` if a matching route was found and handlers were executed,
/// `false` otherwise (caller should send a fallback 404).
pub async fn Router::dispatch(
  self : Router,
  req : @http.Request,
  reader : &@io.Reader,
  conn : @http.ServerConnection,
) -> Bool {
  let meth = Method::from_native(req.meth)
  let path = strip_query(req.path)
  let path_segs = split_path(path)
  let params : Map[String, String] = Map([])

  // Try the requested method's trie first
  match self.roots.get(meth) {
    Some(root) =>
      match search(root, path_segs, 0, params) {
        Some(result) => {
          let ctx = self.build_ctx(req, reader, conn, result)
          self.execute_chain(ctx)
          return true
        }
        None => ()
      }
    None => ()
  }

  // No route found for this method. Check if the path exists for ANY method
  // (to distinguish 404 vs 405)
  let path_exists = check_path_exists(self, path_segs)
  if path_exists {
    // 405: path matches but method not allowed
    if self.no_method_handlers.length() > 0 {
      let result = MatchResult::{
        handlers: self.no_method_handlers,
        params: Map([]),
        node_middlewares: [],
      }
      let ctx = self.build_ctx(req, reader, conn, result)
      self.execute_chain(ctx)
      return true
    }
  }

  // 404: no route matched
  if self.no_route_handlers.length() > 0 {
    let result = MatchResult::{
      handlers: self.no_route_handlers,
      params: Map([]),
      node_middlewares: [],
    }
    let ctx = self.build_ctx(req, reader, conn, result)
    self.execute_chain(ctx)
    return true
  }
  false
}

///|
/// Check whether the given path exists in ANY method's trie.
fn check_path_exists(router : Router, segments : Array[String]) -> Bool {
  for meth in all_methods() {
    match router.roots.get(meth) {
      Some(root) => {
        let params : Map[String, String] = Map([])
        match search(root, segments, 0, params) {
          Some(_) => return true
          None => ()
        }
      }
      None => ()
    }
  }
  false
}

///|
/// Build a Context with the full handler chain.
fn Router::build_ctx(
  self : Router,
  req : @http.Request,
  reader : &@io.Reader,
  conn : @http.ServerConnection,
  result : MatchResult,
) -> Context {
  // Build chain: global middleware + node middleware + route handlers
  let chain : Array[Handler] = []
  for mw in self.global_middleware {
    chain.push(mw)
  }
  for mw in result.node_middlewares {
    chain.push(mw)
  }
  for h in result.handlers {
    chain.push(h)
  }
  let ctx = Context::new(req, reader, ResponseConn::Real(conn), chain)
  ctx.set_params(result.params)
  ctx
}

///|
/// Start executing the handler chain from the first handler.
async fn Router::execute_chain(self : Router, ctx : Context) -> Unit {
  let _ = self
  let chain = ctx.handlers
  if chain.length() > 0 {
    let first = chain[0]
    first(ctx)
  }
}

///|
/// Recursively search the trie for a matching route.
pub fn search(
  node : Node,
  segments : Array[String],
  idx : Int,
  params : Map[String, String],
) -> MatchResult? {
  // If we've consumed all segments, check if this node has handlers
  if idx >= segments.length() {
    if node.handlers.length() > 0 {
      return Some(
        MatchResult::{
          handlers: node.handlers,
          params,
          node_middlewares: node.middlewares,
        },
      )
    }
    return None
  }
  let seg = segments[idx]

  // 1. Try static match first (highest priority)
  match node.children.get(seg) {
    Some(child) => {
      let result = search(child, segments, idx + 1, params)
      match result {
        Some(_) => return result
        None => ()
      }
    }
    None => ()
  }

  // 2. Try param match
  match node.param_child {
    Some(child) => {
      params.set(child.seg, seg)
      match search(child, segments, idx + 1, params) {
        Some(r) => {
          let merged_mw : Array[Handler] = []
          for mw in node.middlewares {
            merged_mw.push(mw)
          }
          for mw in r.node_middlewares {
            merged_mw.push(mw)
          }
          return Some(
            MatchResult::{
              handlers: r.handlers,
              params: r.params,
              node_middlewares: merged_mw,
            },
          )
        }
        None => params.remove(child.seg)
      }
    }
    None => ()
  }

  // 3. Try wildcard match (greedy — captures all remaining segments)
  match node.wildcard_child {
    Some(child) =>
      if child.handlers.length() > 0 {
        // Join remaining segments with "/"
        let mut remaining = ""
        let mut i = idx
        while i < segments.length() {
          if remaining != "" {
            remaining = remaining + "/"
          }
          remaining = remaining + segments[i]
          i = i + 1
        }
        params.set(child.seg, remaining)
        // Merge middlewares from ancestor nodes
        let merged_mw : Array[Handler] = []
        for mw in node.middlewares {
          merged_mw.push(mw)
        }
        for mw in child.middlewares {
          merged_mw.push(mw)
        }
        return Some(
          MatchResult::{
            handlers: child.handlers,
            params,
            node_middlewares: merged_mw,
          },
        )
      }
    None => ()
  }
  None
}

///|
/// Split a path into non-empty segments.
pub fn split_path(path : String) -> Array[String] {
  let parts = path.split("/")
  let segs : Array[String] = []
  for seg in parts {
    if seg != "" {
      segs.push(seg.to_owned())
    }
  }
  segs
}

///|
/// Strip query string from path.
pub fn strip_query(path : String) -> String {
  match path.find("?") {
    Some(pos) => path[:pos].to_owned()
    None => path
  }
}

///| ——————————————————————————————————————————————————————————————————————
///  Route listing
///| ——————————————————————————————————————————————————————————————————————

///|
/// Information about a single registered route.
pub(all) struct RouteInfo {
  meth : String
  path : String
  handler_count : Int
}

///|
/// List all registered routes. Returns an array of (method, path) pairs.
///
/// ```
/// let routes = router.routes()
/// for route in routes {
///   println("\{route.method} \{route.path}")
/// }
/// ```
pub fn Router::routes(self : Router) -> Array[RouteInfo] {
  let result : Array[RouteInfo] = []
  for meth, root in self.roots {
    let method_str = meth.to_string()
    collect_routes(root, method_str, "", result)
  }
  result
}

///|
/// Recursively collect routes from the trie.
fn collect_routes(
  node : Node,
  meth : String,
  prefix : String,
  result : Array[RouteInfo],
) -> Unit {
  // For root node, don't prepend its segment "/" (avoids "///" prefixes).
  let is_root = match node.kind {
    Root => true
    _ => false
  }
  let display = if is_root {
    if prefix == "" {
      "/"
    } else {
      prefix
    }
  } else {
    prefix + "/" + node.seg
  }
  let child_prefix = if is_root { prefix } else { display }
  if node.handlers.length() > 0 {
    result.push(RouteInfo::{
      meth,
      path: display,
      handler_count: node.handlers.length(),
    })
  }
  for _, child in node.children {
    collect_routes(child, meth, child_prefix, result)
  }
  match node.param_child {
    Some(child) => collect_routes(child, meth, child_prefix, result)
    None => ()
  }
  match node.wildcard_child {
    Some(child) => collect_routes(child, meth, child_prefix, result)
    None => ()
  }
}

///|
/// Trees returns a human-readable string representation of all routing trees.
/// Prints routing tree for debugging.
pub fn Router::trees(self : Router) -> String {
  let mut result = ""
  let methods = all_methods()
  for meth in methods {
    match self.roots.get(meth) {
      Some(root) => {
        let method_str = meth.to_string()
        let has_routes = node_has_routes(root)
        if !has_routes {
          continue
        }
        if result != "" {
          result = result + "\n"
        }
        result = result + method_str + "\n"
        print_tree(root, "", true, "", fn(line : String) {
          result = result + line + "\n"
        })
      }
      None => ()
    }
  }
  if result == "" {
    return "(empty)"
  }
  result
}

///|
/// Check if a node or its descendants have any handlers.
fn node_has_routes(node : Node) -> Bool {
  if node.handlers.length() > 0 {
    return true
  }
  for _, child in node.children {
    if node_has_routes(child) {
      return true
    }
  }
  match node.param_child {
    Some(child) => if node_has_routes(child) { return true }
    None => ()
  }
  match node.wildcard_child {
    Some(child) => if node_has_routes(child) { return true }
    None => ()
  }
  false
}

///|
/// Pretty-print a node tree recursively.
fn print_tree(
  node : Node,
  prefix : String,
  is_last : Bool,
  acc : String,
  output : (String) -> Unit,
) -> Unit {
  let connector = if is_last { "└── " } else { "├── " }
  let extension = if is_last { "    " } else { "│   " }

  // Print this node's segment
  let label = match node.kind {
    Root => "/"
    Static => node.seg
    Param => ":" + node.seg
    Wildcard => "*" + node.seg
  }
  let handler_info = if node.handlers.length() > 0 {
    "  [" + node.handlers.length().to_string() + " handler(s)]"
  } else {
    ""
  }
  output(prefix + connector + label + handler_info)

  // Collect all children
  let children : Array[String] = []
  for seg, _ in node.children {
    children.push(seg)
  }

  // Sort children for deterministic output
  children.sort()

  // Print children
  let mut idx = 0
  let total = children.length() +
    (if node.param_child is Some(_) { 1 } else { 0 }) +
    (if node.wildcard_child is Some(_) { 1 } else { 0 })

  // Static children
  for seg in children {
    match node.children.get(seg) {
      Some(child) => {
        let child_is_last = idx == total - 1
        print_tree(
          child,
          prefix + extension,
          child_is_last,
          acc + "/" + seg,
          output,
        )
        idx = idx + 1
      }
      None => ()
    }
  }

  // Param child
  match node.param_child {
    Some(child) => {
      let child_is_last = idx == total - 1
      print_tree(
        child,
        prefix + extension,
        child_is_last,
        acc + "/:" + child.seg,
        output,
      )
      idx = idx + 1
    }
    None => ()
  }

  // Wildcard child
  match node.wildcard_child {
    Some(child) => {
      let child_is_last = idx == total - 1
      print_tree(
        child,
        prefix + extension,
        child_is_last,
        acc + "/*" + child.seg,
        output,
      )
    }
    None => ()
  }
}
