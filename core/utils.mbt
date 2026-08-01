///|
/// Utility functions shared across the framework.
///
/// See `utils.go` equivalent.

///|
/// Join an array of strings with a separator.
pub fn join_strings(strings : Array[String], sep : String) -> String {
  let mut result = ""
  for s in strings {
    if result != "" {
      result = result + sep
    }
    result = result + s
  }
  result
}

///|
/// Guess MIME type from file extension.
pub fn guess_content_type(path : String) -> String {
  let ext = match path.rev_find(".") {
    Some(pos) => path[pos:].to_owned()
    None => ""
  }
  match ext {
    ".html" | ".htm" => "text/html; charset=utf-8"
    ".css" => "text/css; charset=utf-8"
    ".js" => "application/javascript; charset=utf-8"
    ".json" => "application/json; charset=utf-8"
    ".png" => "image/png"
    ".jpg" | ".jpeg" => "image/jpeg"
    ".gif" => "image/gif"
    ".svg" => "image/svg+xml"
    ".ico" => "image/x-icon"
    ".woff" => "font/woff"
    ".woff2" => "font/woff2"
    ".ttf" => "font/ttf"
    ".txt" => "text/plain; charset=utf-8"
    ".xml" => "application/xml; charset=utf-8"
    ".pdf" => "application/pdf"
    _ => "application/octet-stream"
  }
}

///|
/// Simple URL percent-decoding.
pub fn url_decode(s : String) -> String {
  let mut result = ""
  let mut i = 0
  let chars = s.to_array()
  while i < chars.length() {
    let ch = chars[i]
    if ch == '+' {
      result = result + " "
      i = i + 1
    } else if ch == '%' && i + 2 < chars.length() {
      let hex = chars[i + 1].to_string() + chars[i + 2].to_string()
      match parse_hex(hex) {
        Some(byte) => {
          result = result + Int::unsafe_to_char(byte).to_string()
          i = i + 3
        }
        None => {
          result = result + "%"
          i = i + 1
        }
      }
    } else {
      result = result + ch.to_string()
      i = i + 1
    }
  }
  result
}

///|
/// Parse a 2-character hex string to a byte value.
fn parse_hex(hex : String) -> Int? {
  if hex.length() != 2 {
    return None
  }
  let chars = hex.to_array()
  let hi = hex_digit(chars[0])
  let lo = hex_digit(chars[1])
  match (hi, lo) {
    (Some(h), Some(l)) => Some(h * 16 + l)
    _ => None
  }
}

///|
/// Convert a hex char to its numeric value.
fn hex_digit(ch : Char) -> Int? {
  match ch {
    '0' => Some(0)
    '1' => Some(1)
    '2' => Some(2)
    '3' => Some(3)
    '4' => Some(4)
    '5' => Some(5)
    '6' => Some(6)
    '7' => Some(7)
    '8' => Some(8)
    '9' => Some(9)
    'a' | 'A' => Some(10)
    'b' | 'B' => Some(11)
    'c' | 'C' => Some(12)
    'd' | 'D' => Some(13)
    'e' | 'E' => Some(14)
    'f' | 'F' => Some(15)
    _ => None
  }
}
