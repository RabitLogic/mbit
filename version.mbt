///|
/// Version information for the mbit framework.
///
/// See `version.go` equivalent.

///|
/// Framework version string.
pub fn version() -> String {
  "0.1.0"
}

///|
/// Framework name and version for User-Agent headers.
pub fn name_and_version() -> String {
  "mbit/" + version()
}
