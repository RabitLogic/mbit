///|
/// Request binding — extract and validate data from requests.
///
/// inspired by `ShouldBindJSON` / `ShouldBindQuery` but adapted
/// for MoonBit's type system.

///| ——————————————————————————————————————————————————————————————————————
///  JSON body binding
///| ——————————————————————————————————————————————————————————————————————

///|
/// Bind JSON body to a struct that implements `from_json`.
/// Returns `Some(value)` on success, `None` on parse failure.
///
/// ```
/// struct LoginRequest {
///   username : String
///   password : String
/// } derive(FromJson)
///
/// let req : LoginRequest? = bind_json(ctx)
/// ```
pub async fn[T : @json.FromJson] bind_json(ctx : Context) -> T? {
  let json = ctx.body_json()
  match json {
    Some(j) =>
      match (try? @json.from_json(j)) {
        Ok(v) => Some(v)
        Err(_) => None
      }
    None => None
  }
}

///| ——————————————————————————————————————————————————————————————————————
///  Query string binding
///| ——————————————————————————————————————————————————————————————————————

///|
/// Bind query parameters to a struct that implements `from_json`.
/// Converts query string to a JSON object first.
pub fn[T : @json.FromJson] bind_query(ctx : Context) -> T? {
  // Build a JSON object from query parameters
  let obj : Map[String, Json] = {}
  let qs = ctx.full_path()
  match qs.find("?") {
    Some(pos) => {
      let raw = qs[pos + 1:].to_owned()
      let pairs = raw.split("&")
      for pair in pairs {
        match pair.find("=") {
          Some(i) => {
            let k = url_decode(pair[:i].to_owned())
            let v = url_decode(pair[i + 1:].to_owned())
            obj.set(k, Json::string(v))
          }
          None => {
            let k = url_decode(pair.to_owned())
            obj.set(k, Json::string(""))
          }
        }
      }
    }
    None => ()
  }
  let json = Json::object(obj)
  match (try? @json.from_json(json)) {
    Ok(v) => Some(v)
    Err(_) => None
  }
}

///| ——————————————————————————————————————————————————————————————————————
///  Form binding (application/x-www-form-urlencoded)
///| ——————————————————————————————————————————————————————————————————————

///|
/// Bind form-encoded body to a struct that implements `from_json`.
/// Returns `Some(value)` on success, `None` on parse failure.
///
/// ```
/// struct ContactForm {
///   name : String
///   email : String
///   message : String
/// } derive(FromJson)
///
/// let form : ContactForm? = bind_form(ctx)
/// ```
pub async fn[T : @json.FromJson] bind_form(ctx : Context) -> T? {
  let raw = ctx.body_string()
  if raw == "" {
    return None
  }
  let obj : Map[String, Json] = {}
  let pairs = raw.split("&")
  for pair in pairs {
    match pair.find("=") {
      Some(i) => {
        let k = url_decode(pair[:i].to_owned())
        let v = url_decode(pair[i + 1:].to_owned())
        obj.set(k, Json::string(v))
      }
      None => {
        let k = url_decode(pair.to_owned())
        obj.set(k, Json::string(""))
      }
    }
  }
  let json = Json::object(obj)
  match (try? @json.from_json(json)) {
    Ok(v) => Some(v)
    Err(_) => None
  }
}

///| ——————————————————————————————————————————————————————————————————————
///  Header binding
///| ——————————————————————————————————————————————————————————————————————

///|
/// Bind request headers to a struct that implements `from_json`.
/// Header names are normalized to lowercase.
///
/// ```
/// struct Headers {
///   content_type : String
///   authorization : String
/// } derive(FromJson)
///
/// let hdrs : Headers? = bind_header(ctx)
/// ```
pub fn[T : @json.FromJson] bind_header(ctx : Context) -> T? {
  let obj : Map[String, Json] = {}
  // We extract common headers manually since we don't have
  // a full headers iterator on the native request
  let common_headers = [
    "content-type", "accept", "authorization", "user-agent", "host", "origin",
    "referer", "x-forwarded-for", "x-real-ip", "x-request-id", "content-length",
    "cache-control", "cookie",
  ]
  for name in common_headers {
    match ctx.header(name) {
      Some(v) => obj.set(name, Json::string(v))
      None => ()
    }
  }
  let json = Json::object(obj)
  match (try? @json.from_json(json)) {
    Ok(v) => Some(v)
    Err(_) => None
  }
}

///| ——————————————————————————————————————————————————————————————————————
///  Path parameter binding
///| ——————————————————————————————————————————————————————————————————————

///|
/// Bind path parameters to a struct that implements `from_json`.
///
/// ```
/// struct ArticleParams {
///   id : String
///   slug : String
/// } derive(FromJson)
///
/// // Route: /article/:id/:slug
/// let params : ArticleParams? = bind_path(ctx)
/// ```
pub fn[T : @json.FromJson] bind_path(ctx : Context) -> T? {
  let obj : Map[String, Json] = {}
  let all_params = ctx.params_all()
  for k, v in all_params {
    obj.set(k, Json::string(v))
  }
  let json = Json::object(obj)
  match (try? @json.from_json(json)) {
    Ok(v) => Some(v)
    Err(_) => None
  }
}

///| ——————————————————————————————————————————————————————————————————————
///  Combined binding
///| ——————————————————————————————————————————————————————————————————————

///|
/// Try to bind from JSON body first, then fall back to query string.
pub async fn[T : @json.FromJson] bind(ctx : Context) -> T? {
  // Try JSON first
  let json_result : T? = bind_json(ctx)
  match json_result {
    Some(v) => return Some(v)
    None => ()
  }
  // Fall back to query string
  bind_query(ctx)
}

///|
/// Bind URI (path) parameters — alias for `bind_path`.
pub fn[T : @json.FromJson] bind_uri(ctx : Context) -> T? {
  bind_path(ctx)
}

///| ——————————————————————————————————————————————————————————————————————
///  Validation
///| ——————————————————————————————————————————————————————————————————————

///|
/// Internal holder for the bind-validation flag.
priv struct BindValidationBox {
  mut enabled : Bool
}

///|
/// Whether automatic validation is enabled.
let bind_validation_box : BindValidationBox = { enabled: true }

///|
/// Disable automatic validation during binding.
pub fn disable_bind_validation() -> Unit {
  bind_validation_box.enabled = false
}

///|
/// Enable automatic validation during binding.
pub fn enable_bind_validation() -> Unit {
  bind_validation_box.enabled = true
}

///|
/// Check if bind validation is enabled.
pub fn is_bind_validation_enabled() -> Bool {
  bind_validation_box.enabled
}

///|
/// Validate a value and return the first error message, or None if valid.
/// Override this in your types for custom validation.
pub fn[T] validate(_value : T) -> String? {
  None
}

///|
/// Bind is a standalone function that auto-detects content type and binds.
/// Auto-detect content type and bind - alias.
pub async fn[T : @json.FromJson] gin_bind(ctx : Context, _obj : T) -> T? {
  ctx.bind_api()
}
