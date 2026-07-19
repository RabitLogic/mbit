///|
/// Framework mode — controls debug/release/test behavior.
///
/// See `mode.go` equivalent.

///|
/// Framework running mode.
pub(all) enum Mode {
  Debug
  Release
  Test
} derive(Debug, Eq)

///|
/// Convert mode to a display string.
pub fn Mode::to_string(self : Mode) -> String {
  match self {
    Debug => "Debug"
    Release => "Release"
    Test => "Test"
  }
}

///|
/// Internal holder for the mutable current mode.
priv struct ModeBox {
  mut mode : Mode
}

///|
/// Current mode (default: Debug).
let mode_box : ModeBox = { mode: Debug }

///|
/// Set the framework running mode.
///
/// ```
/// set_mode(Release)
/// ```
pub fn set_mode(mode : Mode) -> Unit {
  mode_box.mode = mode
}

///|
/// Get the current running mode.
pub fn mode() -> Mode {
  mode_box.mode
}

///|
/// Whether the framework is in debug mode.
pub fn is_debug() -> Bool {
  mode_box.mode == Debug
}

///|
/// Whether the framework is in release mode.
pub fn is_release() -> Bool {
  mode_box.mode == Release
}
