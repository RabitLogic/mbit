///|
/// Static file serving — serves files from a local directory under a URL prefix.
///
/// See `fs.go` equivalent.
///
/// Usage:
/// ```
/// app.use(static_files("/static", "./public"))
/// ```
pub fn static_files(prefix : String, dir : String) -> Handler {
  async fn(ctx) {
    let path = ctx.path()
    if path.has_prefix(prefix) {
      let file_path = dir + path[prefix.length():].to_owned()
      try {
        let content = @fs.read_file(file_path).text()
        let ct = guess_content_type(file_path)
        ctx.data(200, ct, content)
      } catch {
        _ => ctx.next()
      }
    } else {
      ctx.next()
    }
  }
}

///|
/// Dir returns an HTML directory listing for the given path.
/// Returns an HTML directory listing.
///
/// ```
/// ctx.html(200, dir_listing("./public"))
/// ```
pub async fn dir_listing(dir_path : String) -> String {
  let mut html = "<html><head><title>Directory listing</title></head><body>\n"
  html = html + "<h1>Directory: " + dir_path + "</h1>\n<ul>\n"
  try {
    let files = @fs.readdir(dir_path)
    for file in files {
      html = html + "  <li><a href=\"" + file + "\">" + file + "</a></li>\n"
    }
  } catch {
    _ => html = html + "  <li>Error reading directory</li>\n"
  }
  html = html + "</ul>\n</body></html>"
  html
}
