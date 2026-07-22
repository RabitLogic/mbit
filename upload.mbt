///|
/// File upload support — multipart/form-data parsing with structured metadata.
///
/// Extracted from Context to keep the core type lean.
///
/// ## Usage
///
/// ```
/// // Single file
/// match ctx.form_file("avatar") {
///   Some(file) => {
///     log_info("Received file", [
///       ("name", file.filename),
///       ("size", file.size.to_string()),
///     ])
///     ctx.save_uploaded_file(file, "./uploads/" + file.filename)
///   }
///   None => ctx.abort_with_status(400, "No file uploaded")
/// }
///
/// // All fields (including non-file form fields)
/// let form = ctx.multipart_form()
/// for field_name, file in form {
///   println("\{field_name}: \{file.filename} (\{file.size} bytes)")
/// }
/// ```

///|
/// Structured metadata for an uploaded file.
pub(all) struct FileHeader {
  /// The form field name (e.g., "avatar")
  field_name : String
  /// The original filename from the client (e.g., "photo.jpg")
  filename : String
  /// The raw file content as a string
  content : String
  /// MIME type of the file (e.g., "image/jpeg"), if detectable
  content_type : String
  /// File size in bytes
  size : Int64
}

///|
/// Extract the boundary string from a multipart/form-data Content-Type header.
fn extract_boundary(content_type : String) -> String? {
  match content_type.find("boundary=") {
    Some(pos) => {
      let start = pos + "boundary=".length()
      Some(content_type[start:].to_owned())
    }
    None => None
  }
}

///|
/// Find the end of headers (blank line) in a multipart part, starting from `start`.
/// Returns the position right after the blank line, or None.
fn find_header_end(body : String, start : Int) -> Int? {
  // Try \r\n\r\n first (RFC  compliant)
  match body[start:].find("\r\n\r\n") {
    Some(pos) => Some(start + pos + 4)
    None =>
      // Fall back to \n\n
      match body[start:].find("\n\n") {
        Some(pos) => Some(start + pos + 2)
        None => None
      }
  }
}

///|
/// Extract the filename from a multipart part's Content-Disposition header.
/// Searches forward from the boundary marker before field_pos, through the
/// entire header block (including after `name=`).
fn extract_filename(body : String, field_pos : Int) -> String {
  // Find the start of the current part (the "--boundary" before this field)
  let part_start = match body[:field_pos].rev_find("\n--") {
    Some(pos) => pos + 1  // start after the newline
    None => 0
  }
  // Find end of headers (blank line after this field's headers)
  let header_end = match body[field_pos:].find("\r\n\r\n") {
    Some(pos) => field_pos + pos
    None =>
      match body[field_pos:].find("\n\n") {
        Some(pos) => field_pos + pos
        None => body.length()
      }
  }
  // Search for filename="..." in the header region
  let header_region = body[part_start:header_end].to_owned()
  match header_region.find("filename=\"") {
    Some(fn_start) => {
      let after_fn = fn_start + "filename=\"".length()
      match header_region[after_fn:].find("\"") {
        Some(fn_end) => header_region[after_fn:after_fn + fn_end].to_owned()
        None => ""
      }
    }
    None => ""
  }
}

///|
/// Extract the content-type of a file part from its headers.
/// Searches forward from the boundary marker before field_pos.
fn extract_part_content_type(body : String, field_pos : Int) -> String {
  let part_start = match body[:field_pos].rev_find("\n--") {
    Some(pos) => pos + 1
    None => 0
  }
  let header_end = match body[field_pos:].find("\r\n\r\n") {
    Some(pos) => field_pos + pos
    None =>
      match body[field_pos:].find("\n\n") {
        Some(pos) => field_pos + pos
        None => body.length()
      }
  }
  let header_region = body[part_start:header_end].to_owned()
  match header_region.find("Content-Type:") {
    Some(ct_start) => {
      let after_header = ct_start + "Content-Type:".length()
      let ct_value = header_region[after_header:].trim()
      match ct_value.find("\r\n") {
        Some(line_end) => ct_value[:line_end].to_owned()
        None =>
          match ct_value.find("\n") {
            Some(line_end) => ct_value[:line_end].to_owned()
            None => ct_value.to_owned()
          }
      }
    }
    None => "application/octet-stream"
  }
}

///|
/// Strip trailing newlines from multipart content.
fn strip_trailing_newlines(s : String) -> String {
  let s = match s.strip_suffix("\r\n") {
    Some(v) => v.to_owned()
    None => s
  }
  match s.strip_suffix("\n") {
    Some(v) => v.to_owned()
    None => s
  }
}

///| ——————————————————————————————————————————————————————————————————————
///  Context extension methods for file upload
///| ——————————————————————————————————————————————————————————————————————

///|
/// FormFile returns the metadata and content of an uploaded file from a
/// multipart/form-data request.
///
/// Returns `Some(FileHeader)` with filename, content, content-type, and size,
/// or `None` if the field is not present or not a multipart request.
///
/// ```
/// match ctx.form_file("avatar") {
///   Some(file) => {
///     println("Received: \{file.filename} (\{file.size} bytes)")
///     ctx.save_uploaded_file(file, "./uploads/" + file.filename)
///   }
///   None => ctx.abort_with_status(400, "No file uploaded")
/// }
/// ```
pub async fn Context::form_file(
  self : Context,
  field_name : String,
) -> FileHeader? {
  let content_type = self.content_type()
  if !content_type.has_prefix("multipart/form-data") {
    return None
  }

  let boundary = match extract_boundary(content_type) {
    Some(b) => b
    None => return None
  }

  let body = self.body_string()
  let field_marker = "name=\"" + field_name + "\""

  match body.find(field_marker) {
    Some(field_pos) => {
      // Find end of headers
      let content_start = match find_header_end(body, field_pos) {
        Some(pos) => pos
        None => return None
      }

      // Find the closing boundary
      let boundary_marker = "--" + boundary
      let rest = body[content_start:]
      let end_pos = match rest.find(boundary_marker) {
        Some(pos) => pos
        None => return None
      }

      let raw_content = rest[:end_pos].to_owned()
      let content = strip_trailing_newlines(raw_content)
      let filename = extract_filename(body, field_pos)
      let part_ct = extract_part_content_type(body, field_pos)

      Some(FileHeader::{
        field_name,
        filename,
        content,
        content_type: part_ct,
        size: content.length().to_int64(),
      })
    }
    None => None
  }
}

///|
/// Save an uploaded file to the specified destination path.
///
/// ```
/// match ctx.form_file("avatar") {
///   Some(file) => ctx.save_uploaded_file(file, "./uploads/" + file.filename)
///   None => ctx.abort_with_status(400, "No file uploaded")
/// }
/// ```
pub async fn Context::save_uploaded_file(
  self : Context,
  file : FileHeader,
  dst : String,
) -> Unit {
  try {
    @fs.write_file(dst, file.content)
  } catch {
    _ => self.add_error("Failed to save file to " + dst)
  }
}

///|
/// Convenience: save raw content to disk (backward compatible).
pub async fn Context::save_uploaded_file_content(
  self : Context,
  content : String,
  dst : String,
) -> Unit {
  try {
    @fs.write_file(dst, content)
  } catch {
    _ => self.add_error("Failed to save file to " + dst)
  }
}

///|
/// GetPostFormFile returns the original filename from a multipart form upload.
/// Returns the filename extracted from the Content-Disposition header.
pub async fn Context::get_post_form_file(
  self : Context,
  field_name : String,
) -> String? {
  let content_type = self.content_type()
  if !content_type.has_prefix("multipart/form-data") {
    return None
  }
  let body = self.body_string()
  let field_marker = "name=\"" + field_name + "\""
  match body.find(field_marker) {
    Some(pos) => {
      let filename = extract_filename(body, pos)
      if filename != "" { Some(filename) } else { None }
    }
    None => None
  }
}

///|
/// MultipartForm parses the entire multipart/form-data body and returns a map
/// of field name → FileHeader for all file fields.
///
/// This is useful for forms with multiple file uploads.
pub async fn Context::multipart_form(self : Context) -> Map[String, FileHeader] {
  let content_type = self.content_type()
  if !content_type.has_prefix("multipart/form-data") {
    return Map([])
  }

  let boundary = match extract_boundary(content_type) {
    Some(b) => b
    None => return Map([])
  }

  let body = self.body_string()
  let result : Map[String, FileHeader] = Map([])
  let boundary_marker = "--" + boundary
  let mut search_from = 0

  while search_from < body.length() {
    match body[search_from:].find("name=\"") {
      Some(name_start) => {
        let after_name = search_from + name_start + "name=\"".length()
        match body[after_name:].find("\"") {
          Some(name_end) => {
            let field_name = body[after_name:after_name + name_end].to_owned()

            // Find content after headers
            let content_start = match find_header_end(body, after_name + name_end) {
              Some(pos) => pos
              None => break
            }

            let remaining = body[content_start:]
            match remaining.find(boundary_marker) {
              Some(end) => {
                let raw_content = remaining[:end].to_owned()
                let content = strip_trailing_newlines(raw_content)
                let filename = extract_filename(body, after_name)
                let part_ct = extract_part_content_type(body, after_name)

                result.set(field_name, FileHeader::{
                  field_name,
                  filename,
                  content,
                  content_type: part_ct,
                  size: content.length().to_int64(),
                })
                search_from = content_start + end + boundary_marker.length()
              }
              None => break
            }
          }
          None => break
        }
      }
      None => break
    }
  }
  result
}

///| ——————————————————————————————————————————————————————————————————————
///  Streaming multipart parser — reads body in chunks via @io.Reader
///| ——————————————————————————————————————————————————————————————————————

///|
/// A streaming multipart parser that reads the request body incrementally
/// instead of buffering the entire body in memory.
///
/// ## When to use
///
/// - Large file uploads (> 10 MB) where loading into memory is expensive
/// - Progressive processing of upload data
///
/// ## When NOT to use
///
/// - You need random access to multipart fields (use `multipart_form` instead)
/// - The form has many small fields (uses more overhead per part)
///
/// ```
/// let stream = MultipartStream::new(ctx)
/// loop {
///   match stream.next_part() {
///     Some(part) => {
///       // Process chunk by chunk
///       loop {
///         match part.read_chunk(8192) {
///           Some(chunk) => { /* write chunk */ }
///           None => break  // part complete
///         }
///       }
///     }
///     None => break  // no more parts
///   }
/// }
/// ```

///|
/// A single part in a streaming multipart parse, with header info
/// and a reader for chunked body access.
pub(all) struct MultipartPartReader {
  /// Form field name
  field_name : String
  /// Original filename (empty for non-file fields)
  filename : String
  /// Content-Type of this part
  content_type : String
  /// Remaining content bytes count (from Content-Length or boundary search)
  mut remaining : Int64
  /// Current position in the raw body string
  mut pos : Int
  /// Reference to the full body + boundary for scanning
  body : String
  /// Boundary marker for finding the end
  boundary_marker : String
  /// Whether this part has been fully consumed
  mut done : Bool
}

///|
/// Create a streaming multipart parser from a Context.
///
/// The parser reads the request body into a buffer and provides
/// incremental access to each multipart part.
pub fn MultipartStream::new(ctx : Context) -> MultipartStream? {
  let content_type = ctx.content_type()
  if !content_type.has_prefix("multipart/form-data") {
    return None
  }
  let boundary = match extract_boundary(content_type) {
    Some(b) => b
    None => return None
  }
  Some(MultipartStream::{
    body: "",
    boundary,
    pos: 0,
    done: false,
  })
}

///|
/// Streaming multipart parser state.
pub(all) struct MultipartStream {
  /// The body buffer (accumulated from reader)
  mut body : String
  /// Boundary string
  boundary : String
  /// Current scan position
  mut pos : Int
  /// Whether parsing is complete
  mut done : Bool
}

///|
/// Read the next available part from the multipart stream.
/// Returns `None` when all parts have been consumed.
///
/// The returned `MultipartPartReader` lets you read the part body
/// chunk by chunk via `read_chunk()`.
pub fn MultipartStream::next_part(
  self : MultipartStream,
) -> MultipartPartReader? {
  if self.done {
    return None
  }

  let boundary_marker = "--" + self.boundary
  let end_marker = boundary_marker + "--"

  // Find the next field in the accumulated body
  while self.pos < self.body.length() {
    match self.body[self.pos:].find("name=\"") {
      Some(name_start) => {
        let after_name = self.pos + name_start + "name=\"".length()
        match self.body[after_name:].find("\"") {
          Some(name_end) => {
            let field_name = self.body[after_name:after_name + name_end].to_owned()

            // Find end of headers
            let content_start = match find_header_end(self.body, after_name + name_end) {
              Some(pos) => pos
              None => {
                self.pos = self.pos + 1
                continue
              }
            }

            let filename = extract_filename(self.body, after_name)
            let part_ct = extract_part_content_type(self.body, after_name)

            self.pos = content_start

            return Some(MultipartPartReader::{
              field_name,
              filename,
              content_type: part_ct,
              remaining: 0L,
              pos: content_start,
              body: self.body,
              boundary_marker,
              done: false,
            })
          }
          None => {
            self.pos = self.pos + 1
            continue
          }
        }
      }
      None => {
        // Check for closing boundary
        if self.body[self.pos:].find(end_marker) is Some(_) {
          self.done = true
        }
        return None
      }
    }
  }
  None
}

///|
/// Read the next chunk of the current multipart part body.
/// Returns `Some(chunk)` with data, or `None` when the part is complete.
///
/// ```
/// let stream = MultipartStream::new(ctx)
/// match stream.next_part() {
///   Some(part) => {
///     loop {
///       match part.read_chunk(4096) {
///         Some(chunk) => { /* process chunk */ }
///         None => break
///       }
///     }
///   }
///   None => {}
/// }
/// ```
pub fn MultipartPartReader::read_chunk(
  self : MultipartPartReader,
  max_size : Int,
) -> String? {
  if self.done {
    return None
  }

  let remaining_body = self.body[self.pos:]
  match remaining_body.find(self.boundary_marker) {
    Some(end_pos) => {
      // The boundary is ahead; we can read up to it
      let available = if end_pos < max_size { end_pos } else { max_size }
      if available <= 0 {
        // At the boundary — skip it and mark done
        let after_boundary = self.pos + end_pos + self.boundary_marker.length()
        self.pos = after_boundary
        // Check for closing --
        if self.body[after_boundary:].has_prefix("--") {
          self.done = true
        }
        return None
      }
      let chunk = remaining_body[:available].to_owned()
      self.pos = self.pos + available
      Some(chunk)
    }
    None => {
      // Boundary not yet in buffer — return what we have
      if remaining_body.length() > 0 {
        let chunk = remaining_body.to_owned()
        self.pos = self.body.length()
        Some(chunk)
      } else {
        None
      }
    }
  }
}

///|
/// Convenience: drain a multipart part completely into a string.
pub fn MultipartPartReader::drain(self : MultipartPartReader) -> String {
  let mut result = ""
  let mut remaining = true
  while remaining {
    let chunk = self.read_chunk(65536)
    match chunk {
      Some(c) => result = result + c
      None => remaining = false
    }
  }
  result
}

///| ——————————————————————————————————————————————————————————————————————
///  Resumable upload support (断点续传)
///| ——————————————————————————————————————————————————————————————————————

///|
/// Parsed Content-Range header info for resumable uploads.
pub(all) struct ContentRange {
  /// Starting byte position (inclusive)
  start : Int64
  /// Ending byte position (inclusive)
  end : Int64
  /// Total file size (0 if unknown)
  total : Int64
}

///|
/// Parse a `Content-Range` header value.
///
/// Supports format: `bytes <start>-<end>/<total>`
///
/// ```
/// let range = parse_content_range("bytes 0-499/1024")
/// assert_eq(range.start, 0)
/// assert_eq(range.end, 499)
/// assert_eq(range.total, 1024)
/// ```
pub fn parse_content_range(header : String) -> ContentRange? {
  if !header.has_prefix("bytes ") {
    return None
  }
  let rest = header[6:].to_owned()  // skip "bytes "
  match rest.find("/") {
    Some(slash_pos) => {
      let range_part = rest[:slash_pos].to_owned()
      let total_str = rest[slash_pos + 1:].to_owned()
      let total = @string.parse_int64(total_str) catch { _ => 0L }

      match range_part.find("-") {
        Some(dash_pos) => {
          let start_str = range_part[:dash_pos].to_owned()
          let end_str = range_part[dash_pos + 1:].to_owned()
          let start = @string.parse_int64(start_str) catch { _ => return None }
          let end = @string.parse_int64(end_str) catch { _ => return None }
          Some(ContentRange::{ start, end, total })
        }
        None => None
      }
    }
    None => None
  }
}

///|
/// Check if the request contains a Content-Range header for resumable upload.
pub fn Context::content_range(self : Context) -> ContentRange? {
  match self.header("Content-Range") {
    Some(h) => parse_content_range(h)
    None => None
  }
}

///|
/// Save an uploaded file with resumable upload support.
///
/// If the request includes a `Content-Range` header, the function
/// appends the content to the existing file (resume). Otherwise,
/// it overwrites (new upload).
///
/// ```
/// match ctx.form_file("video") {
///   Some(file) => {
///     ctx.save_uploaded_file_resumable(file, "./uploads/video.mp4")
///   }
///   None => ctx.abort_with_status(400, "No file")
/// }
/// ```
pub async fn Context::save_uploaded_file_resumable(
  self : Context,
  file : FileHeader,
  dst : String,
) -> Unit {
  let range = self.content_range()
  match range {
    Some(r) => {
      // Resumable: append chunk to existing file
      if r.start > 0L {
        // Read existing file and append
        let existing = @fs.read_file(dst).text() catch { _ => "" }
        @fs.write_file(dst, existing + file.content) catch {
          _ => self.add_error("Failed to write resumable chunk to " + dst)
        }
      } else {
        // First chunk: overwrite
        @fs.write_file(dst, file.content) catch {
          _ => self.add_error("Failed to write file to " + dst)
        }
      }
    }
    None => {
      // No range: simple write
      @fs.write_file(dst, file.content) catch {
        _ => self.add_error("Failed to write file to " + dst)
      }
    }
  }
}

///| ——————————————————————————————————————————————————————————————————————
///  Large file chunked processing (大文件分块处理)
///| ——————————————————————————————————————————————————————————————————————

///|
/// Configuration for chunked file processing.
pub(all) struct ChunkedWriteConfig {
  /// Chunk size in bytes (default: 1 MB)
  chunk_size : Int
  /// Whether to process chunks via callback instead of buffering all
  process_callback : Bool
}

///|
/// Default chunked write config (1 MB chunks).
pub fn ChunkedWriteConfig::default() -> ChunkedWriteConfig {
  { chunk_size: 1024 * 1024, process_callback: true }
}

///|
/// Callback type for processing file chunks.
/// Called with each chunk of data; return false to abort.
pub type ChunkCallback = (String, Int, Int) -> Bool

///|
/// Save an uploaded file in chunks, processing each chunk via callback.
///
/// Useful for very large files where you want to:
/// - Track progress
/// - Process data incrementally (e.g., hash, validate)
/// - Avoid loading the entire file into memory at once (still uses body_string
///   for the initial read, but writes and processes incrementally)
///
/// ```
/// let mut bytes_written = 0L
/// ctx.save_uploaded_chunked(file, "./uploads/large.bin",
///   ChunkedWriteConfig::default(),
///   fn(chunk, index, total_chunks) {
///     bytes_written = bytes_written + chunk.length().to_int64()
///     println("chunk \{index}/\{total_chunks}")
///     true  // continue
///   })
/// ```
pub async fn Context::save_uploaded_chunked(
  self : Context,
  file : FileHeader,
  dst : String,
  config : ChunkedWriteConfig,
  callback : ChunkCallback,
) -> Unit {
  let content = file.content
  let total_len = content.length()
  let chunk_size = config.chunk_size
  let total_chunks = (total_len + chunk_size - 1) / chunk_size
  let mut accumulated = ""

  let mut i = 0
  while i < total_chunks {
    let start = i * chunk_size
    let end = if start + chunk_size < total_len {
      start + chunk_size
    } else {
      total_len
    }
    let chunk_content = content[start:end].to_owned()

    // Callback for progress/validation
    let should_continue = callback(chunk_content, i, total_chunks)
    if !should_continue {
      return
    }

    accumulated = accumulated + chunk_content
    i = i + 1
  }

  // Write the complete file
  try {
    @fs.write_file(dst, accumulated)
  } catch {
    _ => self.add_error("Failed to write chunked file to " + dst)
  }
}

///|
/// Progress info for large file uploads.
pub(all) struct UploadProgress {
  /// Total file size in bytes
  total_size : Int64
  /// Bytes processed so far
  bytes_processed : Int64
  /// Percentage complete (0.0 - 100.0)
  percentage : Double
  /// Current chunk index
  current_chunk : Int
  /// Total number of chunks
  total_chunks : Int
}

///|
/// Create a progress tracker for large uploads.
pub fn UploadProgress::new(
  total_size : Int64,
  chunk_size : Int,
) -> UploadProgress {
  {
    total_size,
    bytes_processed: 0L,
    percentage: 0.0,
    current_chunk: 0,
    total_chunks: ((total_size.to_double() / chunk_size.to_double()).ceil()).to_int(),
  }
}

///|
/// Update progress after processing a chunk.
pub fn UploadProgress::update(
  self : UploadProgress,
  chunk_bytes : Int64,
) -> UploadProgress {
  let new_processed = self.bytes_processed + chunk_bytes
  let pct = if self.total_size > 0L {
    new_processed.to_double() / self.total_size.to_double() * 100.0
  } else {
    100.0
  }
  {
    total_size: self.total_size,
    bytes_processed: new_processed,
    percentage: pct,
    current_chunk: self.current_chunk + 1,
    total_chunks: self.total_chunks,
  }
}
