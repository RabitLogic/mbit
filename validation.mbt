///|
/// Validation framework — validates struct fields with declarative rules.
///
/// inspired by `binding:"required,min=1"` tags and `validator.v9`.
/// Since MoonBit doesn't have struct tags, validation uses a
/// function-based API: `validate_struct(value, rules)`.

///|
/// A single validation rule for a field.
pub(all) enum Rule {
  /// Field must not be empty
  Required
  /// Minimum string length or numeric value
  Min(Int)
  /// Maximum string length or numeric value
  Max(Int)
  /// Exact string length
  Len(Int)
  /// Must match a regular expression pattern
  Pattern(String)
  /// Must be one of the allowed values
  OneOf(Array[String])
  /// Must be a valid email (basic check: contains @)
  Email
  /// Must be a valid URL (basic check: has scheme)
  URL
  /// Custom validation function, returns error message or None if valid
  Custom((String) -> String?)
}

///|
/// Field validation rules — maps field name to an array of rules.
/// Example:
/// ```
/// let rules = [FieldRules("username", [Required, Min(3), Max(20)]),
///              FieldRules("email", [Required, Email]),
///              FieldRules("age", [Min(0), Max(150)])]
/// ```
pub(all) struct FieldRules {
  field : String
  rules : Array[Rule]
}

///|
/// Create field rules.

pub fn FieldRules::new(field : String, rules : Array[Rule]) -> FieldRules {
  { field, rules }
}

///|
/// A validation error for a single field.
pub(all) struct ValidationError {
  field : String
  message : String
} derive(Show)

///|
/// Collection of validation errors.
pub(all) struct ValidationErrors {
  errors : Array[ValidationError]
}

///|
/// Create a new empty ValidationErrors.
pub fn ValidationErrors::new() -> ValidationErrors {
  { errors: [] }
}

///|
/// Add a validation error.
pub fn ValidationErrors::add(self : ValidationErrors, field : String, message : String) -> Unit {
  self.errors.push({ field, message })
}

///|
/// All validation errors.
pub fn ValidationErrors::all(self : ValidationErrors) -> Array[ValidationError] {
  self.errors
}

///|
/// Whether there are any errors.
pub fn ValidationErrors::has_errors(self : ValidationErrors) -> Bool {
  self.errors.length() > 0
}

///|
/// Get the first error message, if any.
pub fn ValidationErrors::first_error(self : ValidationErrors) -> String? {
  if self.errors.length() > 0 {
    Some(self.errors[0].field + ": " + self.errors[0].message)
  } else {
    None
  }
}

///|
/// Convert validation errors to a JSON response body.
pub fn ValidationErrors::to_json(self : ValidationErrors) -> Json {
  let obj : Map[String, Json] = {}
  for err in self.errors {
    obj.set(err.field, Json::string(err.message))
  }
  Json::object(obj)
}

///|
/// Error string for a ValidationError.
pub fn ValidationError::to_string(self : ValidationError) -> String {
  self.field + ": " + self.message
}

///| ——————————————————————————————————————————————————————————————————————
///  Validation functions
///| ——————————————————————————————————————————————————————————————————————

///|
/// Validate a single field value against a list of rules.
/// Returns `Some(error_message)` if validation fails, `None` if valid.
pub fn validate_field(value : String, rules : Array[Rule]) -> String? {
  for rule in rules {
    match rule {
      Required => {
        if value == "" {
          return Some("is required")
        }
      }
      Min(n) => {
        // Try numeric comparison first
        match (try? @string.parse_int64(value)) {
          Ok(num) =>
            if num < n.to_int64() {
              return Some("must be at least " + n.to_string())
            }
          Err(_) =>
            if value.length() < n {
              return Some("must be at least " + n.to_string() + " characters")
            }
        }
      }
      Max(n) =>
        match (try? @string.parse_int64(value)) {
          Ok(num) =>
            if num > n.to_int64() {
              return Some("must be at most " + n.to_string())
            }
          Err(_) =>
            if value.length() > n {
              return Some("must be at most " + n.to_string() + " characters")
            }
        }
      Len(n) => {
        if value.length() != n {
          return Some("must be exactly " + n.to_string() + " characters")
        }
      }
      Pattern(pattern) => {
        // Simple pattern matching: check if value contains the pattern
        if !value.find(pattern).is_some() && value != pattern {
          return Some("does not match pattern " + pattern)
        }
      }
      OneOf(allowed) => {
        let mut found = false
        for a in allowed {
          if a == value {
            found = true
            break
          }
        }
        if !found {
          return Some("must be one of the allowed values")
        }
      }
      Email => {
        if !value.find("@").is_some() || !value.find(".").is_some() {
          return Some("must be a valid email address")
        }
        let at_pos = match value.find("@") {
          Some(p) => p
          None => {
            // unreachable due to check above, but handle gracefully
            return Some("must be a valid email address")
          }
        }
        if at_pos == 0 || at_pos == value.length() - 1 {
          return Some("must be a valid email address")
        }
      }
      URL => {
        if !(value.has_prefix("http://") || value.has_prefix("https://")) {
          return Some("must be a valid URL (http:// or https://)")
        }
      }
      Custom(f) =>
        match f(value) {
          Some(msg) => return Some(msg)
          None => ()
        }
    }
  }
  None
}

///|
/// Validate a map of field values against field rules.
/// Returns `ValidationErrors` containing all validation failures.
///
/// ```
/// let values = Map([("username", "alice"), ("email", "alice@example.com")])
/// let rules = [
///   FieldRules::new("username", [Required, Min(3)]),
///   FieldRules::new("email", [Required, Email]),
/// ]
/// let errors = validate_map(values, rules)
/// if errors.has_errors() {
///   ctx.json(400, errors.to_json())
///   return
/// }
/// ```
pub fn validate_map(
  values : Map[String, String],
  field_rules : Array[FieldRules],
) -> ValidationErrors {
  let errors = ValidationErrors::new()
  for fr in field_rules {
    let value = match values.get(fr.field) {
      Some(v) => v
      None => ""
    }
    match validate_field(value, fr.rules) {
      Some(msg) => errors.add(fr.field, msg)
      None => ()
    }
  }
  errors
}

///|
/// Convenience: validate and abort with 422 if there are errors.
/// Returns `true` if valid, `false` if aborted.
///
/// ```
/// let values = Map([("username", "alice")])
/// let rules = [FieldRules::new("username", [Required, Min(3)])]
/// if !validate_or_abort(ctx, values, rules) {
///   return
/// }
/// // Proceed with valid data...
/// ```
pub async fn validate_or_abort(
  ctx : Context,
  values : Map[String, String],
  rules : Array[FieldRules],
) -> Bool {
  let errors = validate_map(values, rules)
  if errors.has_errors() {
    ctx.abort_with_status(422, match errors.first_error() {
      Some(e) => e
      None => "Validation failed"
    })
    return false
  }
  true
}
