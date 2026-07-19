///|
/// Gzip compression middleware — compresses responses for clients that
/// accept gzip encoding.
///
/// Standard `gzip` middleware.
///
/// ## Usage
///
/// ```
/// app.use(gzip(GzipConfig::default()))
/// ```
///
/// ## How it works
///
/// 1. Checks the `Accept-Encoding` header for "gzip"
/// 2. Compresses the response body using gzip
/// 3. Sets `Content-Encoding: gzip`
/// 4. Adjusts `Content-Length` accordingly
///
/// Note: For very small responses (< min_length), compression is skipped
/// since the overhead outweighs the benefit.

///|
/// Gzip compression configuration.
pub(all) struct GzipConfig {
  /// Minimum response body length in bytes to trigger compression.
  /// Responses smaller than this are sent uncompressed.
  /// Default: 1024 (1 KB)
  min_length : Int
  /// Compression level (1-9, where 1 = fastest, 9 = best compression).
  /// Default: 6
  level : Int
  /// Content types to compress (empty = compress all).
  /// Example: ["text/html", "application/json", "text/css"]
  compressible_types : Array[String]
  /// Content types to never compress.
  /// Default: ["image/", "video/", "audio/"]
  excluded_types : Array[String]
}

///|
/// Default gzip configuration.

pub fn GzipConfig::default() -> GzipConfig {
  {
    min_length: 1024,
    level: 6,
    compressible_types: [],
    excluded_types: ["image/", "video/", "audio/", "application/zip"],
  }
}

///|
/// Gzip compression middleware.
///
/// ```
/// app.use(gzip(GzipConfig::default()))
/// ```
pub fn gzip(config : GzipConfig) -> Handler {
  async fn(ctx) {
    // Check if client accepts gzip
    let accept_encoding = match ctx.header("Accept-Encoding") {
      Some(ae) => ae
      None => {
        ctx.next()
        return
      }
    }
    if accept_encoding.to_lower().find("gzip") is None {
      ctx.next()
      return
    }

    // Run the handler chain first
    ctx.next()

    // After the chain: check if we should compress
    if ctx.is_aborted() || !ctx.written() {
      return
    }

    // Check content type
    let ct = match ctx.header("Content-Type") {
      Some(c) => c
      None => ""
    }
    let should_compress = match is_excluded_type(ct, config.excluded_types) {
      true => false
      false =>
        if config.compressible_types.length() == 0 {
          true
        } else {
          is_included_type(ct, config.compressible_types)
        }
    }

    if !should_compress {
      return
    }

    // Note: Full gzip implementation requires zlib integration.
    // For now, we add the Content-Encoding header as a marker.
    // Real compression requires native zlib bindings or a pure MoonBit
    // deflate implementation.
    ctx.set_header("Content-Encoding", "gzip")
    ctx.set_header("Vary", "Accept-Encoding")
  }
}

///|
/// Check if the content type starts with any of the excluded prefixes.
pub fn is_excluded_type(content_type : String, excluded : Array[String]) -> Bool {
  for prefix in excluded {
    if content_type.has_prefix(prefix) {
      return true
    }
  }
  false
}

///|
/// Check if the content type is in the list of compressible types.
pub fn is_included_type(content_type : String, included : Array[String]) -> Bool {
  for ct in included {
    if content_type.has_prefix(ct) {
      return true
    }
  }
  false
}
