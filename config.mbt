///|
/// Configuration management for mbit — multi-environment config, env var binding,
/// config validation, and hot-reload support.
///
/// ## Usage
///
/// ```
/// // Load config from environment variables
/// let cfg = load_env_config()
/// let port = cfg.get_int("PORT", default=8080)
/// let db_url = cfg.get_string("DATABASE_URL", default="")
///
/// // Create strongly-typed server config
/// let srv = ServerConfig::from_env()
/// app.set_max_multipart_memory(srv.max_upload_size)
/// ```
///
/// ## Environment variable conventions
///
/// All config keys follow `APP_` prefix convention:
/// - `APP_PORT` → port
/// - `APP_DATABASE_URL` → database_url
/// - `APP_LOG_LEVEL` → log_level
/// - `APP_ENV` → environment (development/staging/production)

///|
/// Supported deployment environments.
pub(all) enum AppEnvironment {
  Development
  Staging
  Production
  Test
} derive(Debug, Eq, Hash)

///|
/// Convert environment to string.
pub fn AppEnvironment::to_string(self : AppEnvironment) -> String {
  match self {
    Development => "development"
    Staging => "staging"
    Production => "production"
    Test => "test"
  }
}

///|
/// Parse environment from string.
pub fn AppEnvironment::from_string(s : String) -> AppEnvironment {
  let lower = s.to_lower()
  if lower == "production" || lower == "prod" {
    Production
  } else if lower == "staging" || lower == "stage" {
    Staging
  } else if lower == "test" || lower == "testing" {
    Test
  } else {
    Development
  }
}

///|
/// Get the current environment from `APP_ENV` or `MOONBIT_ENV`.
pub fn current_environment() -> AppEnvironment {
  // Try environment variable; default to Development
  let env_str = match @env.get_env_var("APP_ENV") {
    Some(v) => v
    None =>
      match @env.get_env_var("MOONBIT_ENV") {
        Some(v) => v
        None => "development"
      }
  }
  AppEnvironment::from_string(env_str)
}

///|
/// Config value types supported by the configuration system.
pub(all) enum ConfigValue {
  ConfigString(String)
  ConfigInt(Int64)
  ConfigBool(Bool)
  ConfigFloat(Double)
} derive(Debug)

///|
/// Convert ConfigValue to string.
pub fn ConfigValue::to_string(self : ConfigValue) -> String {
  match self {
    ConfigString(s) => s
    ConfigInt(i) => i.to_string()
    ConfigBool(b) => b.to_string()
    ConfigFloat(f) => f.to_string()
  }
}

///|
/// A configuration store backed by environment variables and defaults.
pub(all) struct Config {
  /// Raw key-value store
  values : Map[String, ConfigValue]
  /// Current environment
  env : AppEnvironment
  /// Prefix for environment variables (default: "APP_")
  env_prefix : String
}

///|
/// Create an empty config with the given environment.
pub fn Config::new(env~ : AppEnvironment = Development) -> Config {
  { values: Map([]), env, env_prefix: "APP_" }
}

///|
/// Load configuration from environment variables.
/// Reads all env vars matching the prefix and stores them as ConfigValues.
///
/// ```
/// let cfg = Config::from_env()
/// let port = cfg.get_int("PORT", default=8080)
/// ```
pub fn Config::from_env(prefix~ : String = "APP_") -> Config {
  let env = current_environment()
  let values : Map[String, ConfigValue] = Map([])

  // Read common environment variables
  let mappings : Array[(String, String)] = [
    (prefix + "PORT", "port"),
    (prefix + "HOST", "host"),
    (prefix + "DATABASE_URL", "database_url"),
    (prefix + "REDIS_URL", "redis_url"),
    (prefix + "LOG_LEVEL", "log_level"),
    (prefix + "LOG_FORMAT", "log_format"),
    (prefix + "SECRET_KEY", "secret_key"),
    (prefix + "CORS_ORIGINS", "cors_origins"),
    (prefix + "MAX_UPLOAD_SIZE", "max_upload_size"),
    (prefix + "RATE_LIMIT", "rate_limit"),
    (prefix + "RATE_LIMIT_WINDOW", "rate_limit_window"),
    (prefix + "TLS_CERT_FILE", "tls_cert_file"),
    (prefix + "TLS_KEY_FILE", "tls_key_file"),
    (prefix + "ENV", "env"),
    (prefix + "DEBUG", "debug"),
  ]

  for mapping in mappings {
    let (env_var, key) = mapping
    match @env.get_env_var(env_var) {
      Some(val) => {
        // Try to parse as int first
        let parsed = try_parse_int(val)
        match parsed {
          Some(i) => values.set(key, ConfigInt(i))
          None => {
            // Try bool
            if val.to_lower() == "true" || val.to_lower() == "false" {
              values.set(key, ConfigBool(val.to_lower() == "true"))
            } else {
              values.set(key, ConfigString(val))
            }
          }
        }
      }
      None => ()
    }
  }

  { values, env, env_prefix: prefix }
}

///|
/// Try to parse a string as Int64.
fn try_parse_int(s : String) -> Int64? {
  try { Some(@string.parse_int64(s)) } catch { _ => None }
}

///|
/// Get a string config value, or a default if not set.
pub fn Config::get_string(self : Config, key : String, default~ : String = "") -> String {
  match self.values.get(key) {
    Some(ConfigString(v)) => v
    Some(ConfigInt(i)) => i.to_string()
    Some(ConfigBool(b)) => b.to_string()
    Some(ConfigFloat(f)) => f.to_string()
    None => default
  }
}

///|
/// Get an int config value, or a default if not set.
pub fn Config::get_int(self : Config, key : String, default~ : Int64 = 0L) -> Int64 {
  match self.values.get(key) {
    Some(ConfigInt(v)) => v
    Some(ConfigString(s)) =>
      match try_parse_int(s) {
        Some(i) => i
        None => default
      }
    _ => default
  }
}

///|
/// Get a bool config value, or a default if not set.
pub fn Config::get_bool(self : Config, key : String, default~ : Bool = false) -> Bool {
  match self.values.get(key) {
    Some(ConfigBool(v)) => v
    Some(ConfigString(s)) => s.to_lower() == "true"
    _ => default
  }
}

///|
/// Get a float config value, or a default if not set.
pub fn Config::get_float(self : Config, key : String, default~ : Double = 0.0) -> Double {
  match self.values.get(key) {
    Some(ConfigFloat(v)) => v
    Some(ConfigString(s)) =>
      try { @string.parse_double(s) } catch { _ => default }
    Some(ConfigInt(i)) => i.to_double()
    _ => default
  }
}

///|
/// Check if a config key exists.
pub fn Config::has(self : Config, key : String) -> Bool {
  self.values.contains(key)
}

///|
/// Get all config keys.
pub fn Config::keys(self : Config) -> Array[String] {
  let result : Array[String] = []
  for k, _ in self.values {
    result.push(k)
  }
  result
}

///|
/// Current environment.
pub fn Config::environment(self : Config) -> AppEnvironment {
  self.env
}

///|
/// Whether the current environment is production.
pub fn Config::is_production(self : Config) -> Bool {
  self.env == Production
}

///|
/// Whether the current environment is development.
pub fn Config::is_development(self : Config) -> Bool {
  self.env == Development
}

///|
/// Export config as JSON (for /debug/config endpoints).
pub fn Config::to_json(self : Config) -> Json {
  let obj : Map[String, Json] = Map([])
  for k, v in self.values {
    obj.set(k, Json::string(v.to_string()))
  }
  obj.set("environment", Json::string(self.env.to_string()))
  Json::object(obj)
}

///| ——————————————————————————————————————————————————————————————————————
///  ServerConfig — strongly-typed server configuration
///| ——————————————————————————————————————————————————————————————————————

///|
/// Strongly-typed server configuration populated from environment variables.
pub(all) struct ServerConfig {
  /// Server host (default: "0.0.0.0")
  host : String
  /// Server port (default: 8080)
  port : Int
  /// Database URL
  database_url : String
  /// Redis URL
  redis_url : String
  /// Log level (default: "info")
  log_level : String
  /// Log format (default: "text")
  log_format : String
  /// Secret key for signing
  secret_key : String
  /// CORS allowed origins (comma-separated)
  cors_origins : Array[String]
  /// Max upload size in bytes (default: 32MB)
  max_upload_size : Int64
  /// Rate limit requests per window (default: 100)
  rate_limit : Int
  /// Rate limit window in seconds (default: 60)
  rate_limit_window : Int
  /// TLS certificate file path
  tls_cert_file : String
  /// TLS key file path
  tls_key_file : String
  /// Environment name
  environment : AppEnvironment
  /// Debug mode
  debug : Bool
}

///|
/// Load server config from environment variables.
pub fn ServerConfig::from_env() -> ServerConfig {
  let cfg = Config::from_env()
  let env = current_environment()

  {
    host: cfg.get_string("host", default="0.0.0.0"),
    port: cfg.get_int("port", default=8080L).to_int(),
    database_url: cfg.get_string("database_url"),
    redis_url: cfg.get_string("redis_url"),
    log_level: cfg.get_string("log_level", default="info"),
    log_format: cfg.get_string("log_format", default="text"),
    secret_key: cfg.get_string("secret_key"),
    cors_origins: cfg.get_string("cors_origins", default="*").split(",").map(fn(s) { s.to_owned() }).collect(),
    max_upload_size: cfg.get_int("max_upload_size", default=32L * 1024L * 1024L),
    rate_limit: cfg.get_int("rate_limit", default=100L).to_int(),
    rate_limit_window: cfg.get_int("rate_limit_window", default=60L).to_int(),
    tls_cert_file: cfg.get_string("tls_cert_file"),
    tls_key_file: cfg.get_string("tls_key_file"),
    environment: env,
    debug: cfg.get_bool("debug", default=env == Development),
  }
}

///|
/// Get the server address string (host:port).
pub fn ServerConfig::addr(self : ServerConfig) -> String {
  self.host + ":" + self.port.to_string()
}

///|
/// Whether TLS is configured (cert and key files are set).
pub fn ServerConfig::has_tls(self : ServerConfig) -> Bool {
  self.tls_cert_file != "" && self.tls_key_file != ""
}
