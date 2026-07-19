///|
/// Debug utilities — debug logging and route registration output.
///
/// See `debug.go` equivalent.

///|
/// Debug print with format — for general debug logging.
/// Only prints in debug mode.
pub fn debug_print(msg : String) -> Unit {
  if is_debug() {
    println("[mbit] " + msg)
  }
}

///|
/// Debug print for route registration.
pub fn debug_print_route(meth : String, path : String) -> Unit {
  if is_debug() {
    println("[mbit] " + meth + " " + path)
  }
}

///|
/// Debug warning print.
pub fn debug_print_warning(msg : String) -> Unit {
  if is_debug() {
    println("[mbit-warn] " + msg)
  }
}

///|
/// Debug print for engine creation.
pub fn debug_print_new() -> Unit {
  if is_debug() {
    println("[mbit] Creating new Engine")
  }
}

///|
/// Debug print for default engine creation (with middleware).
pub fn debug_print_default() -> Unit {
  if is_debug() {
    println("[mbit] Creating Engine with Logger + Recovery middleware")
  }
}

///|
/// Debug print for server start.
pub fn debug_print_listen(addr : String) -> Unit {
  if is_debug() {
    println("[mbit] Listening and serving HTTP on " + addr)
  }
}
