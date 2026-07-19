///|
/// Error types for the mbit framework.

///|
/// HTTP method enumeration
pub(all) enum Method {
  GET
  POST
  PUT
  DELETE
  PATCH
  HEAD
  OPTIONS
} derive(Show, Eq, Hash, @debug.Debug)

///|
/// Convert from native HTTP RequestMethod
pub fn Method::from_native(meth : @http.RequestMethod) -> Method {
  match meth {
    Get => GET
    Post => POST
    Put => PUT
    Delete => DELETE
    Patch => PATCH
    Head => HEAD
    Options => OPTIONS
    _ => GET
  }
}

///|
/// Convert to native HTTP RequestMethod
pub fn Method::to_native(self : Method) -> @http.RequestMethod {
  match self {
    GET => Get
    POST => Post
    PUT => Put
    DELETE => Delete
    PATCH => Patch
    HEAD => Head
    OPTIONS => Options
  }
}

///|
/// Convert Method to string
pub fn Method::to_string(self : Method) -> String {
  match self {
    GET => "GET"
    POST => "POST"
    PUT => "PUT"
    DELETE => "DELETE"
    PATCH => "PATCH"
    HEAD => "HEAD"
    OPTIONS => "OPTIONS"
  }
}

///|
/// Framework-level error for binding / validation
pub(all) enum MbitError {
  BindError(String)
  ValidationError(String)
  NotFound(String)
  InternalError(String)
} derive(Show)

///|
/// Standard HTTP status codes used by the framework
pub fn status_text(code : Int) -> String {
  match code {
    200 => "OK"
    201 => "Created"
    204 => "No Content"
    301 => "Moved Permanently"
    302 => "Found"
    304 => "Not Modified"
    400 => "Bad Request"
    401 => "Unauthorized"
    403 => "Forbidden"
    404 => "Not Found"
    405 => "Method Not Allowed"
    409 => "Conflict"
    413 => "Payload Too Large"
    422 => "Unprocessable Entity"
    429 => "Too Many Requests"
    500 => "Internal Server Error"
    502 => "Bad Gateway"
    503 => "Service Unavailable"
    _ => "Unknown"
  }
}
