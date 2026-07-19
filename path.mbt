///|
/// Path utilities for URL cleaning and manipulation.
///
/// See `path.go` equivalent.

///|
/// Clean a URL path by removing duplicate slashes and resolving ".." and ".".
pub fn clean_path(path : String) -> String {
  if path == "" {
    return "/"
  }
  // Split by "/", filter empty segments, resolve ".." and "."
  let segments = path.split("/")
  let cleaned : Array[String] = []
  for seg in segments {
    if seg == "" || seg == "." {
      continue
    }
    if seg == ".." {
      if cleaned.length() > 0 {
        let _ = cleaned.pop()
      }
      continue
    }
    cleaned.push(seg.to_owned())
  }
  if cleaned.length() == 0 {
    return "/"
  }
  let mut result = ""
  for seg in cleaned {
    result = result + "/" + seg
  }
  result
}
