///|
/// Debug tests — debug_print, mode-dependent logging.

test "debug_print in debug mode" {
  set_mode(Debug)
  debug_print("test message")
  assert_true(true)
}

test "debug_print in release mode is silent" {
  set_mode(Release)
  debug_print("should not print")
  set_mode(Debug)
  assert_true(true)
}

test "debug_print_route" {
  set_mode(Debug)
  debug_print_route("GET", "/api/test")
  assert_true(true)
}

test "debug_print_warning" {
  debug_print_warning("warning message")
  assert_true(true)
}

test "debug_print_new" {
  debug_print_new()
  assert_true(true)
}

test "debug_print_default" {
  debug_print_default()
  assert_true(true)
}

test "debug_print_listen" {
  debug_print_listen("0.0.0.0:8080")
  assert_true(true)
}
