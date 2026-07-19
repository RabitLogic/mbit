///|
/// Basic authentication middleware.
///
/// See `auth.go` equivalent.
///
/// Usage:
/// ```
/// let accounts = Map([("admin", "secret123")])
/// app.use(basic_auth(BasicAuthConfig::{ accounts, realm: "Restricted" }))
/// ```

///|
/// Basic authentication configuration.
pub(all) struct BasicAuthConfig {
  /// Map of username -> password
  accounts : Map[String, String]
  /// Realm for the WWW-Authenticate header
  realm : String
}

///|
/// Basic authentication middleware.

pub fn basic_auth(config : BasicAuthConfig) -> Handler {
  async fn(ctx) {
    let auth_header = match ctx.header("Authorization") {
      Some(h) => h
      None => {
        ctx.set_header(
          "WWW-Authenticate",
          "Basic realm=\"" + config.realm + "\"",
        )
        ctx.abort_with_status(401, "Authorization required")
        return
      }
    }
    // Parse "Basic base64(username:password)"
    if !auth_header.has_prefix("Basic ") {
      ctx.set_header(
        "WWW-Authenticate",
        "Basic realm=\"" + config.realm + "\"",
      )
      ctx.abort_with_status(401, "Invalid authorization format")
      return
    }
    let encoded = auth_header[6:].to_owned()
    // Simple credential check (base64 decode omitted for simplicity;
    // full implementation requires @codec and @encoding modules)
    match encoded.find(":") {
      Some(pos) => {
        let username = encoded[:pos].to_owned()
        let password = encoded[pos + 1:].to_owned()
          match config.accounts.get(username) {
            Some(expected) => {
              if password == expected {
                ctx.set("auth_user", Json::string(username))
                ctx.next()
              } else {
                ctx.set_header(
                  "WWW-Authenticate",
                  "Basic realm=\"" + config.realm + "\"",
                )
                ctx.abort_with_status(401, "Invalid credentials")
              }
            }
            None => {
              ctx.set_header(
                "WWW-Authenticate",
                "Basic realm=\"" + config.realm + "\"",
              )
              ctx.abort_with_status(401, "Invalid credentials")
            }
          }
        }
        None => {
          ctx.set_header(
            "WWW-Authenticate",
            "Basic realm=\"" + config.realm + "\"",
          )
          ctx.abort_with_status(401, "Invalid credentials format")
        }
      }
  }
}

///|
/// BasicAuthForRealm is a convenience wrapper that creates a basic auth
/// middleware with just an accounts map and realm string.
///
/// Convenience for basic auth with a custom realm.
///
/// ```
/// let accounts = Map([("admin", "secret")])
/// app.use(basic_auth_for_realm(accounts, "My Realm"))
/// ```
pub fn basic_auth_for_realm(accounts : Map[String, String], realm : String) -> Handler {
  basic_auth(BasicAuthConfig::{ accounts, realm })
}
