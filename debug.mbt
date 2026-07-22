///|
/// Debug utilities — debug logging and route registration output.
///
/// All output goes through `Logger::debug()`, respecting log levels and formats.
/// Only visible in debug mode (`is_debug()` returns true).

///|
/// Debug print with format — for general debug logging.
/// Only prints in debug mode.
pub fn debug_print(msg : String) -> Unit {
  if is_debug() {
    Logger::debug(msg)
  }
}

///|
/// Debug print for route registration.
pub fn debug_print_route(meth : String, path : String) -> Unit {
  if is_debug() {
    Logger::debug(meth + " " + path, fields=[("type", "route")])
  }
}

///|
/// Debug warning print — logged at Warn level.
pub fn debug_print_warning(msg : String) -> Unit {
  if is_debug() {
    Logger::warn(msg, fields=[("source", "framework")])
  }
}

///|
/// Debug print for engine creation.
pub fn debug_print_new() -> Unit {
  if is_debug() {
    Logger::debug("Creating new Engine")
  }
}

///|
/// Debug print for default engine creation (with middleware).
pub fn debug_print_default() -> Unit {
  if is_debug() {
    Logger::debug("Creating Engine with Logger + Recovery middleware")
  }
}

///|
/// Debug print for server start.
pub fn debug_print_listen(addr : String) -> Unit {
  if is_debug() {
    Logger::debug("Listening and serving HTTP on " + addr, fields=[("addr", addr)])
  }
}
