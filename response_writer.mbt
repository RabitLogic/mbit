///|
/// ResponseWriter — abstraction over the HTTP response writing.
///
/// See `response_writer.go` equivalent.
/// Provides size tracking, status tracking, and write methods.

///|
/// ResponseWriter wraps the response connection with size tracking.
pub(all) struct ResponseWriter {
  conn : ResponseConn
  mut size : Int
  mut status : Int
  mut written : Bool
}

///|
pub fn ResponseWriter::new(conn : ResponseConn) -> ResponseWriter {
  { conn, size: 0, status: 200, written: false }
}

///|
/// WriteHeader sends the HTTP response header with the given status code.
pub async fn ResponseWriter::write_header(
  self : ResponseWriter,
  code : Int,
) -> Unit {
  if !self.written {
    self.status = code
    self.conn.send_response(code, status_text(code), extra_headers=Map([]))
    self.written = true
  }
}

///|
/// Write data to the response body.
pub async fn ResponseWriter::write(self : ResponseWriter, data : String) -> Unit {
  if !self.written {
    self.write_header(self.status)
  }
  self.size = self.size + data.length()
  self.conn.write_body(data)
}

///|
/// WriteString writes a string to the response.
pub async fn ResponseWriter::write_string(
  self : ResponseWriter,
  s : String,
) -> Unit {
  self.write(s)
}

///|
/// Size returns the number of bytes written.
pub fn ResponseWriter::size(self : ResponseWriter) -> Int {
  self.size
}

///|
/// Status returns the HTTP status code.
pub fn ResponseWriter::status(self : ResponseWriter) -> Int {
  self.status
}

///|
/// Written returns true if the header has been written.
pub fn ResponseWriter::written(self : ResponseWriter) -> Bool {
  self.written
}

///|
/// Flush any buffered data to the client.
pub async fn ResponseWriter::flush(self : ResponseWriter) -> Unit {
  self.conn.flush()
}

///|
/// WriteHeaderNow forces the response header to be written immediately.
pub async fn ResponseWriter::write_header_now(self : ResponseWriter) -> Unit {
  if !self.written {
    self.conn.send_response(self.status, status_text(self.status), extra_headers=Map([]))
    self.written = true
  }
}

///|
/// EndResponse signals the end of the response.
pub async fn ResponseWriter::end(self : ResponseWriter) -> Unit {
  self.conn.end_response()
}
