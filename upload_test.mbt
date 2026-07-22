///|
/// Upload tests — real multipart data, FileHeader, ContentRange, streaming, progress.

///| ——————————————————————————————————————————————————————————————————————
///  Helpers: build a Context with real multipart/form-data body
///| ——————————————————————————————————————————————————————————————————————

///|
/// A multipart part struct for building test data.
struct MultipartTestPart {
  field_name : String
  filename : String?
  content_type : String?
  content : String
}

///|
/// Build a raw multipart body string from parts.
fn build_multipart_body(boundary : String, parts : Array[MultipartTestPart]) -> String {
  let mut body = ""
  for part in parts {
    body = body + "--" + boundary + "\r\n"
    let mut disposition = "Content-Disposition: form-data; name=\"" + part.field_name + "\""
    match part.filename {
      Some(f) => disposition = disposition + "; filename=\"" + f + "\""
      None => ()
    }
    body = body + disposition + "\r\n"
    match part.content_type {
      Some(ct) => body = body + "Content-Type: " + ct + "\r\n"
      None => ()
    }
    body = body + "\r\n"
    body = body + part.content + "\r\n"
  }
  body = body + "--" + boundary + "--\r\n"
  body
}

///|
/// Create a test Context with real multipart/form-data request body.
fn create_multipart_context(parts : Array[MultipartTestPart]) -> Context {
  let boundary = "----TestBoundary12345"
  let body = build_multipart_body(boundary, parts)
  let content_type = "multipart/form-data; boundary=" + boundary

  let native_method : @http.RequestMethod = Post
  let headers : Map[String, String] = Map([
    ("Content-Type", content_type),
  ])
  let req : @http.Request = { meth: native_method, path: "/upload", headers }
  let conn = ResponseConn::Test(TestConn::new())
  let (_reader, writer) = @io.pipe()
  writer.close()
  let ctx = Context::new(req, _reader, conn, [])
  ctx.body = Some(body)
  ctx
}

///|
/// Multipart body with one text field (no filename).
let single_text_field : Array[MultipartTestPart] = [
  { field_name: "username", filename: None, content_type: None, content: "alice" },
]

///|
/// Multipart body with one file.
let single_file : Array[MultipartTestPart] = [
  { field_name: "avatar", filename: Some("photo.jpg"), content_type: Some("image/jpeg"), content: "fake-image-binary-data" },
]

///|
/// Multipart body with multiple fields and files.
let multi_part : Array[MultipartTestPart] = [
  { field_name: "username", filename: None, content_type: None, content: "alice" },
  { field_name: "avatar", filename: Some("photo.jpg"), content_type: Some("image/jpeg"), content: "binary-image-data" },
  { field_name: "bio", filename: None, content_type: None, content: "Hello World" },
  { field_name: "document", filename: Some("report.pdf"), content_type: Some("application/pdf"), content: "%PDF-1.4 binary..." },
]

///|
/// Multipart body with empty file content.
let empty_file : Array[MultipartTestPart] = [
  { field_name: "file", filename: Some("empty.txt"), content_type: Some("text/plain"), content: "" },
]

///| ——————————————————————————————————————————————————————————————————————
///  FileHeader
///| ——————————————————————————————————————————————————————————————————————

test "FileHeader construction" {
  let f = FileHeader::{
    field_name: "avatar",
    filename: "photo.jpg",
    content: "fake-image-data",
    content_type: "image/jpeg",
    size: 15L,
  }
  assert_eq(f.field_name, "avatar")
  assert_eq(f.filename, "photo.jpg")
  assert_eq(f.content, "fake-image-data")
  assert_eq(f.content_type, "image/jpeg")
  assert_eq(f.size, 15L)
}

test "FileHeader empty filename" {
  let f = FileHeader::{
    field_name: "field",
    filename: "",
    content: "",
    content_type: "application/octet-stream",
    size: 0L,
  }
  assert_eq(f.filename, "")
  assert_eq(f.size, 0L)
}

test "FileHeader large size" {
  let f = FileHeader::{
    field_name: "video",
    filename: "movie.mp4",
    content: "x",
    content_type: "video/mp4",
    size: 1073741824L,
  }
  assert_eq(f.size, 1073741824L)
}

///| ——————————————————————————————————————————————————————————————————————
///  REAL multipart form parsing tests
///| ——————————————————————————————————————————————————————————————————————

async test "form_file parses single file field" {
  let ctx = create_multipart_context(single_file)
  let result = ctx.form_file("avatar")
  match result {
    Some(file) => {
      assert_eq(file.field_name, "avatar")
      assert_eq(file.filename, "photo.jpg")
      assert_eq(file.content_type, "image/jpeg")
      assert_eq(file.content, "fake-image-binary-data")
    }
    None => assert_true(false)
  }
}

async test "form_file parses text field (no filename)" {
  let ctx = create_multipart_context(single_text_field)
  let result = ctx.form_file("username")
  match result {
    Some(file) => {
      assert_eq(file.field_name, "username")
      assert_eq(file.filename, "")
      assert_eq(file.content, "alice")
      assert_eq(file.size, 5L)
    }
    None => assert_true(false)
  }
}

async test "form_file returns None for missing field" {
  let ctx = create_multipart_context(single_file)
  let result = ctx.form_file("nonexistent")
  assert_true(result is None)
}

async test "form_file returns None for non-multipart" {
  let ctx = create_test_context("POST", "/upload")
  let result = ctx.form_file("file")
  assert_true(result is None)
}

async test "form_file parses empty file content" {
  let ctx = create_multipart_context(empty_file)
  let result = ctx.form_file("file")
  match result {
    Some(file) => {
      assert_eq(file.filename, "empty.txt")
      assert_eq(file.content, "")
      assert_eq(file.size, 0L)
    }
    None => assert_true(false)
  }
}

async test "get_post_form_file returns filename" {
  let ctx = create_multipart_context(single_file)
  let name = ctx.get_post_form_file("avatar")
  match name {
    Some(n) => assert_eq(n, "photo.jpg")
    None => assert_true(false)
  }
}

async test "get_post_form_file returns None for text field" {
  let ctx = create_multipart_context(single_text_field)
  let name = ctx.get_post_form_file("username")
  assert_true(name is None)
}

async test "get_post_form_file returns None for missing field" {
  let ctx = create_multipart_context(single_file)
  let name = ctx.get_post_form_file("missing")
  assert_true(name is None)
}

async test "get_post_form_file returns None for non-multipart" {
  let ctx = create_test_context("POST", "/upload")
  let name = ctx.get_post_form_file("file")
  assert_true(name is None)
}

async test "multipart_form parses all fields" {
  let ctx = create_multipart_context(multi_part)
  let form = ctx.multipart_form()
  assert_eq(form.length(), 4)
}

async test "multipart_form contains expected keys" {
  let ctx = create_multipart_context(multi_part)
  let form = ctx.multipart_form()
  assert_true(form.contains("username"))
  assert_true(form.contains("avatar"))
  assert_true(form.contains("bio"))
  assert_true(form.contains("document"))
}

async test "multipart_form file field has correct metadata" {
  let ctx = create_multipart_context(multi_part)
  let form = ctx.multipart_form()
  match form.get("avatar") {
    Some(file) => {
      assert_eq(file.filename, "photo.jpg")
      assert_eq(file.content_type, "image/jpeg")
      assert_eq(file.content, "binary-image-data")
    }
    None => assert_true(false)
  }
}

async test "multipart_form text field has no filename" {
  let ctx = create_multipart_context(multi_part)
  let form = ctx.multipart_form()
  match form.get("username") {
    Some(file) => {
      assert_eq(file.filename, "")
      assert_eq(file.content, "alice")
    }
    None => assert_true(false)
  }
}

async test "multipart_form returns empty for non-multipart" {
  let ctx = create_test_context("POST", "/upload")
  let form = ctx.multipart_form()
  assert_eq(form.length(), 0)
}

async test "multipart_form handles single field" {
  let ctx = create_multipart_context(single_text_field)
  let form = ctx.multipart_form()
  assert_eq(form.length(), 1)
  match form.get("username") {
    Some(file) => assert_eq(file.content, "alice")
    None => assert_true(false)
  }
}

async test "multipart_form handles empty file" {
  let ctx = create_multipart_context(empty_file)
  let form = ctx.multipart_form()
  assert_eq(form.length(), 1)
  match form.get("file") {
    Some(file) => {
      assert_eq(file.content, "")
      assert_eq(file.size, 0L)
    }
    None => assert_true(false)
  }
}

///| ——————————————————————————————————————————————————————————————————————
///  ContentRange / Resumable upload
///| ——————————————————————————————————————————————————————————————————————

test "parse_content_range valid first chunk" {
  let r = parse_content_range("bytes 0-499/1024")
  match r {
    Some(cr) => {
      assert_eq(cr.start, 0L)
      assert_eq(cr.end, 499L)
      assert_eq(cr.total, 1024L)
    }
    None => assert_true(false)
  }
}

test "parse_content_range mid chunk" {
  let r = parse_content_range("bytes 500-999/2048")
  match r {
    Some(cr) => {
      assert_eq(cr.start, 500L)
      assert_eq(cr.end, 999L)
      assert_eq(cr.total, 2048L)
    }
    None => assert_true(false)
  }
}

test "parse_content_range final chunk" {
  let r = parse_content_range("bytes 500-999/1000")
  match r {
    Some(cr) => {
      assert_eq(cr.start, 500L)
      assert_eq(cr.end, 999L)
      assert_eq(cr.total, 1000L)
    }
    None => assert_true(false)
  }
}

test "parse_content_range unknown total" {
  let r = parse_content_range("bytes 0-499/*")
  match r {
    Some(cr) => {
      assert_eq(cr.start, 0L)
      assert_eq(cr.end, 499L)
      assert_eq(cr.total, 0L)
    }
    None => assert_true(false)
  }
}

test "parse_content_range single byte" {
  let r = parse_content_range("bytes 0-0/1")
  match r {
    Some(cr) => {
      assert_eq(cr.start, 0L)
      assert_eq(cr.end, 0L)
      assert_eq(cr.total, 1L)
    }
    None => assert_true(false)
  }
}

test "parse_content_range large file" {
  let r = parse_content_range("bytes 1048576-2097151/10485760")
  match r {
    Some(cr) => {
      assert_eq(cr.start, 1048576L)
      assert_eq(cr.end, 2097151L)
      assert_eq(cr.total, 10485760L)
    }
    None => assert_true(false)
  }
}

test "parse_content_range empty returns None" {
  assert_true(parse_content_range("") is None)
}

test "parse_content_range invalid prefix returns None" {
  assert_true(parse_content_range("chunk 0-99/100") is None)
}

test "parse_content_range no slash returns None" {
  assert_true(parse_content_range("bytes 0-99") is None)
}

test "parse_content_range no dash returns None" {
  assert_true(parse_content_range("bytes 099/100") is None)
}

test "parse_content_range negative start returns None" {
  assert_true(parse_content_range("bytes -1-99/100") is None)
}

test "ContentRange struct construction" {
  let cr = ContentRange::{ start: 0L, end: 999L, total: 5000L }
  assert_eq(cr.start, 0L)
  assert_eq(cr.end, 999L)
  assert_eq(cr.total, 5000L)
}

test "ContentRange single byte range" {
  let cr = ContentRange::{ start: 512L, end: 512L, total: 1024L }
  assert_eq(cr.start, 512L)
  assert_eq(cr.end, 512L)
  assert_eq(cr.total, 1024L)
}

test "Context content_range no header returns None" {
  let ctx = create_test_context("GET", "/upload")
  let cr = ctx.content_range()
  assert_true(cr is None)
}

///| ——————————————————————————————————————————————————————————————————————
///  MultipartStream
///| ——————————————————————————————————————————————————————————————————————

test "MultipartStream new with non-multipart returns None" {
  let ctx = create_test_context("POST", "/upload")
  let stream = MultipartStream::new(ctx)
  assert_true(stream is None)
}

///| ——————————————————————————————————————————————————————————————————————
///  UploadProgress
///| ——————————————————————————————————————————————————————————————————————

test "UploadProgress new defaults" {
  let p = UploadProgress::new(1000L, 256)
  assert_eq(p.total_size, 1000L)
  assert_eq(p.bytes_processed, 0L)
  assert_eq(p.percentage, 0.0)
  assert_eq(p.current_chunk, 0)
}

test "UploadProgress update one chunk" {
  let p = UploadProgress::new(1000L, 256)
  let p = p.update(256L)
  assert_eq(p.bytes_processed, 256L)
  assert_eq(p.current_chunk, 1)
  assert_true(p.percentage > 25.0)
  assert_true(p.percentage < 26.0)
}

test "UploadProgress update multiple chunks" {
  let p = UploadProgress::new(1000L, 256)
  let p = p.update(256L)
  let p = p.update(256L)
  let p = p.update(256L)
  assert_eq(p.bytes_processed, 768L)
  assert_eq(p.current_chunk, 3)
}

test "UploadProgress update completes at 100%" {
  let p = UploadProgress::new(500L, 256)
  let p = p.update(256L)
  let p = p.update(244L)
  assert_eq(p.bytes_processed, 500L)
  assert_eq(p.current_chunk, 2)
  assert_true(p.percentage >= 99.9)
}

test "UploadProgress zero total" {
  let p = UploadProgress::new(0L, 256)
  assert_eq(p.total_size, 0L)
  assert_eq(p.percentage, 0.0)
}

test "UploadProgress update with zero chunk" {
  let p = UploadProgress::new(1000L, 256)
  let p = p.update(0L)
  assert_eq(p.bytes_processed, 0L)
  assert_eq(p.current_chunk, 1)
  assert_eq(p.percentage, 0.0)
}

test "UploadProgress total_chunks calculation" {
  let p = UploadProgress::new(1000L, 256)
  // ceil(1000/256) = 4
  assert_eq(p.total_chunks, 4)
}

test "UploadProgress exact multiple chunks" {
  let p = UploadProgress::new(1024L, 256)
  assert_eq(p.total_chunks, 4)
}

///| ——————————————————————————————————————————————————————————————————————
///  ChunkedWriteConfig
///| ——————————————————————————————————————————————————————————————————————

test "ChunkedWriteConfig default size" {
  let c = ChunkedWriteConfig::default()
  assert_eq(c.chunk_size, 1048576)
  assert_true(c.process_callback)
}

test "ChunkedWriteConfig custom size" {
  let c = ChunkedWriteConfig::{ chunk_size: 512, process_callback: false }
  assert_eq(c.chunk_size, 512)
  assert_false(c.process_callback)
}

test "ChunkedWriteConfig large chunk" {
  let c = ChunkedWriteConfig::{ chunk_size: 65536, process_callback: true }
  assert_eq(c.chunk_size, 65536)
  assert_true(c.process_callback)
}

async test "save_uploaded_file_content does not crash" {
  let ctx = create_test_context("POST", "/upload")
  ctx.save_uploaded_file_content("data", "/tmp/nonexistent_dir/file.txt")
  assert_true(true)
}
