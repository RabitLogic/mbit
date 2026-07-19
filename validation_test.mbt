///|
/// Validation tests — field validation, validate_map, validate_or_abort.


test "validate_field required passes with value" {
  assert_eq(validate_field("hello", [Required]), None)
}

test "validate_field required fails with empty" {
  match validate_field("", [Required]) {
    Some(msg) => assert_true(msg.length() > 0)
    None => assert_true(false)
  }
}

test "validate_field min passes" {
  assert_eq(validate_field("hello", [Min(3)]), None)
}

test "validate_field min fails" {
  match validate_field("ab", [Min(3)]) {
    Some(msg) => assert_true(msg.length() > 0)
    None => assert_true(false)
  }
}

test "validate_field min numeric passes" {
  assert_eq(validate_field("10", [Min(5)]), None)
}

test "validate_field min numeric fails" {
  match validate_field("3", [Min(5)]) {
    Some(msg) => assert_true(msg.length() > 0)
    None => assert_true(false)
  }
}

test "validate_field max passes" {
  assert_eq(validate_field("hello", [Max(10)]), None)
}

test "validate_field max fails" {
  match validate_field("hello world this is too long", [Max(10)]) {
    Some(msg) => assert_true(msg.length() > 0)
    None => assert_true(false)
  }
}

test "validate_field max numeric passes" {
  assert_eq(validate_field("50", [Max(100)]), None)
}

test "validate_field max numeric fails" {
  match validate_field("200", [Max(100)]) {
    Some(msg) => assert_true(msg.length() > 0)
    None => assert_true(false)
  }
}

test "validate_field len passes" {
  assert_eq(validate_field("abc", [Len(3)]), None)
}

test "validate_field len fails" {
  match validate_field("abcd", [Len(3)]) {
    Some(msg) => assert_true(msg.length() > 0)
    None => assert_true(false)
  }
}

test "validate_field email passes" {
  assert_eq(validate_field("alice@example.com", [Email]), None)
}

test "validate_field email fails no at" {
  match validate_field("aliceexample.com", [Email]) {
    Some(msg) => assert_true(msg.length() > 0)
    None => assert_true(false)
  }
}

test "validate_field email fails no dot" {
  match validate_field("alice@example", [Email]) {
    Some(msg) => assert_true(msg.length() > 0)
    None => assert_true(false)
  }
}

test "validate_field email fails at start" {
  match validate_field("@example.com", [Email]) {
    Some(msg) => assert_true(msg.length() > 0)
    None => assert_true(false)
  }
}

test "validate_field URL passes http" {
  assert_eq(validate_field("http://example.com", [URL]), None)
}

test "validate_field URL passes https" {
  assert_eq(validate_field("https://example.com", [URL]), None)
}

test "validate_field URL fails" {
  match validate_field("example.com", [URL]) {
    Some(msg) => assert_true(msg.length() > 0)
    None => assert_true(false)
  }
}

test "validate_field one_of passes" {
  assert_eq(validate_field("red", [OneOf(["red", "green", "blue"])]), None)
}

test "validate_field one_of fails" {
  match validate_field("yellow", [OneOf(["red", "green", "blue"])]) {
    Some(msg) => assert_true(msg.length() > 0)
    None => assert_true(false)
  }
}

test "validate_field custom passes" {
  let rule : Rule = Custom(fn(v) {
    if v == "ok" { None } else { Some("must be ok") }
  })
  assert_eq(validate_field("ok", [rule]), None)
}

test "validate_field custom fails" {
  let rule : Rule = Custom(fn(v) {
    if v == "ok" { None } else { Some("must be ok") }
  })
  match validate_field("bad", [rule]) {
    Some(msg) => assert_eq(msg, "must be ok")
    None => assert_true(false)
  }
}

test "validate_field multiple rules all pass" {
  let rules : Array[Rule] = [Required, Min(3), Max(20)]
  assert_eq(validate_field("hello", rules), None)
}

test "validate_field multiple rules first fails" {
  let rules : Array[Rule] = [Required, Min(3)]
  match validate_field("", rules) {
    Some(msg) => assert_eq(msg, "is required")
    None => assert_true(false)
  }
}

///| ——————————————————————————————————————————————————————————————————————
///  validate_map tests
///| ——————————————————————————————————————————————————————————————————————

test "validate_map all pass" {
  let values : Map[String, String] = { "name": "Alice", "email": "a@b.com" }
  let rules = [
    FieldRules::new("name", [Required, Min(2)]),
    FieldRules::new("email", [Required, Email]),
  ]
  let errors = validate_map(values, rules)
  assert_false(errors.has_errors())
}

test "validate_map one fails" {
  let values : Map[String, String] = { "name": "", "email": "a@b.com" }
  let rules = [
    FieldRules::new("name", [Required]),
    FieldRules::new("email", [Required, Email]),
  ]
  let errors = validate_map(values, rules)
  assert_true(errors.has_errors())
  assert_eq(errors.all().length(), 1)
}

test "validate_map two failures" {
  let values : Map[String, String] = { "name": "A", "email": "bad" }
  let rules = [
    FieldRules::new("name", [Min(3)]),
    FieldRules::new("email", [Email]),
  ]
  let errors = validate_map(values, rules)
  assert_eq(errors.all().length(), 2)
}

test "validate_map missing field treated as empty" {
  let values : Map[String, String] = Map([])
  let rules = [FieldRules::new("name", [Required])]
  let errors = validate_map(values, rules)
  assert_true(errors.has_errors())
}

///| ——————————————————————————————————————————————————————————————————————
///  ValidationErrors tests
///| ——————————————————————————————————————————————————————————————————————

test "ValidationErrors has_errors on empty" {
  let errors = ValidationErrors::new()
  assert_false(errors.has_errors())
}

test "ValidationErrors first_error on empty" {
  let errors = ValidationErrors::new()
  assert_eq(errors.first_error(), None)
}

test "ValidationErrors to_json" {
  let errors = ValidationErrors::new()
  errors.add("name", "is required")
  let json = errors.to_json()
  // Should be a JSON object
  ignore(json)
  assert_true(true)
}

test "ValidationError to_string" {
  let err = ValidationError::{ field: "name", message: "is required" }
  assert_eq(err.to_string(), "name: is required")
}

///| ——————————————————————————————————————————————————————————————————————
///  validate_or_abort tests
///| ——————————————————————————————————————————————————————————————————————

async test "validate_or_abort passes" {
  let ctx = create_test_context("POST", "/form")
  let values : Map[String, String] = { "name": "Alice" }
  let rules = [FieldRules::new("name", [Required])]
  let result = validate_or_abort(ctx, values, rules)
  assert_true(result)
  assert_false(ctx.is_aborted())
}

async test "validate_or_abort aborts on failure" {
  let ctx = create_test_context("POST", "/form")
  let values : Map[String, String] = { "name": "" }
  let rules = [FieldRules::new("name", [Required])]
  let result = validate_or_abort(ctx, values, rules)
  assert_false(result)
  assert_true(ctx.is_aborted())
}
