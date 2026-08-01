///|
/// Debug utilities — debug logging and route registration output.
///
/// See `debug.go` equivalent.

///|
/// Format the current UTC time as `YYYY-MM-DD HH:MM:SS.mmm UTC`, used to
/// prefix debug output so it can be correlated with request logs.
fn debug_ts() -> String {
  let ms = @env.now()
  let day_ms : UInt64 = 86400000
  let days = ms / day_ms
  let rem = ms % day_ms
  let h = rem / 3600000
  let m = (rem / 60000) % 60
  let s = (rem / 1000) % 60
  let millis = rem % 1000
  let (y, mo, d) = civil_from_days(days.to_int64())
  pad4(y.to_string()) + "-" + pad2(mo.to_string()) + "-" + pad2(d.to_string()) + " " +
  pad2(h.to_string()) + ":" + pad2(m.to_string()) + ":" + pad2(s.to_string()) + "." +
  pad3(millis.to_string()) + " UTC"
}

///|
/// Convert days since the Unix epoch to a Gregorian (year, month, day)
/// tuple using Howard Hinnant's `civil_from_days` algorithm (UTC).
fn civil_from_days(days : Int64) -> (Int64, Int64, Int64) {
  let z = days + 719468L
  let era = z / 146097L
  let doe = z - era * 146097L
  let yoe = (doe - doe / 1460L + doe / 36524L - doe / 146096L) / 365L
  let y = yoe + era * 400L
  let doy = doe - (365L * yoe + yoe / 4L - yoe / 100L)
  let mp = (5L * doy + 2L) / 153L
  let d = doy - (153L * mp + 2L) / 5L + 1L
  let m = if mp < 10L { mp + 3L } else { mp - 9L }
  let yy = if m <= 2L { y + 1L } else { y }
  (yy, m, d)
}

///|
/// Zero-pad a number string to at least two digits (e.g. "7" -> "07").
fn pad2(s : String) -> String {
  if s.length() < 2 { "0" + s } else { s }
}

///|
/// Zero-pad a number string to at least three digits (e.g. "7" -> "007").
fn pad3(s : String) -> String {
  if s.length() < 2 {
    "00" + s
  } else if s.length() < 3 {
    "0" + s
  } else {
    s
  }
}

///|
/// Zero-pad a number string to at least four digits (e.g. "24" -> "0024").
fn pad4(s : String) -> String {
  let len = s.length()
  if len >= 4 {
    s
  } else if len == 3 {
    "0" + s
  } else if len == 2 {
    "00" + s
  } else if len == 1 {
    "000" + s
  } else {
    "0000"
  }
}

///|
/// Debug print with format — for general debug logging.
/// Only prints in debug mode.
pub fn debug_print(msg : String) -> Unit {
  if is_debug() {
    println(debug_ts() + "  " + msg)
  }
}

///|
/// Debug print for route registration.
pub fn debug_print_route(meth : String, path : String) -> Unit {
  if is_debug() {
    println(debug_ts() + "  route " + meth + " " + path)
  }
}

///|
/// Debug warning print.
pub fn debug_print_warning(msg : String) -> Unit {
  if is_debug() {
    println(debug_ts() + "  warning: " + msg)
  }
}

///|
/// Debug print for engine creation.
pub fn debug_print_new() -> Unit {
  if is_debug() {
    println(debug_ts() + "  engine created")
  }
}

///|
/// Debug print for default engine creation (with middleware).
pub fn debug_print_default() -> Unit {
  if is_debug() {
    println(debug_ts() + "  engine created with logger + recovery middleware")
  }
}

///|
/// Debug print for server start.
pub fn debug_print_listen(addr : String) -> Unit {
  if is_debug() {
    println(debug_ts() + "  listening on " + addr)
  }
}
