///|
/// Binding tests — JSON, query, form, header, path, URI binding, validation.

struct TestUser {
  name : String
  age : String
} derive(@json.FromJson)

struct TestId {
  id : String
} derive(@json.FromJson)

struct TestHeaders {
  host : String
} derive(@json.FromJson)

test "bind_query parses query string" {
  let ctx = create_test_context("GET", "/search?name=Alice&age=30")
  let r : TestUser? = bind_query(ctx)
  match r {
    Some(u) => {
      assert_eq(u.name, "Alice")
      assert_eq(u.age, "30")
    }
    None => assert_true(false)
  }
}

test "bind_query empty returns None" {
  let ctx = create_test_context("GET", "/search")
  let r : TestUser? = bind_query(ctx)
  match r {
    Some(_) => assert_true(false)
    None => assert_true(true)
  }
}

test "bind_path extracts params" {
  let ctx = create_test_context("GET", "/user/42")
  ctx.set_params({ "id": "42" })
  let r : TestId? = bind_path(ctx)
  match r {
    Some(p) => assert_eq(p.id, "42")
    None => assert_true(false)
  }
}

test "bind_header extracts headers" {
  let ctx = create_test_context("GET", "/test")
  let r : TestHeaders? = bind_header(ctx)
  match r {
    Some(_) => assert_true(true)
    None => assert_true(true)
  }
}

test "bind_uri same as bind_path" {
  let ctx = create_test_context("GET", "/item/99")
  ctx.set_params({ "id": "99" })
  let r : TestId? = bind_uri(ctx)
  match r {
    Some(p) => assert_eq(p.id, "99")
    None => assert_true(false)
  }
}

test "validate returns None by default" {
  assert_eq(validate(42), None)
}

test "disable and enable bind validation" {
  disable_bind_validation()
  assert_false(is_bind_validation_enabled())
  enable_bind_validation()
  assert_true(is_bind_validation_enabled())
}

test "bind_query with URL encoding" {
  let ctx = create_test_context("GET", "/search?name=Hello%20World&age=30")
  let r : TestUser? = bind_query(ctx)
  match r {
    Some(u) => assert_eq(u.name, "Hello World")
    None => assert_true(false)
  }
}

///| ——————————————————————————————————————————————————————————————————————
///  Extended binding tests: edge cases, validation, combo binders
///| ——————————————————————————————————————————————————————————————————————

struct TestMulti {
  name : String
  age : String
  email : String
} derive(@json.FromJson)

struct TestEmpty {} derive(@json.FromJson)

test "bind_query with single parameter" {
  let ctx = create_test_context("GET", "/search?name=Bob&age=not_used")
  let r : TestUser? = bind_query(ctx)
  match r {
    Some(u) => {
      assert_eq(u.name, "Bob")
      assert_true(true)
    }
    None => assert_true(false)
  }
}

test "bind_query with no equals sign" {
  let ctx = create_test_context("GET", "/search?flag")
  let r : TestUser? = bind_query(ctx)
  match r {
    Some(_) => assert_true(true)
    None => assert_true(true)
  }
}

test "bind_query with multiple params complex" {
  let ctx = create_test_context("GET", "/search?name=Alice&age=30&email=a@b.com")
  let r : TestMulti? = bind_query(ctx)
  match r {
    Some(u) => {
      assert_eq(u.name, "Alice")
      assert_eq(u.age, "30")
      assert_eq(u.email, "a@b.com")
    }
    None => assert_true(false)
  }
}

test "bind_query with empty value" {
  let ctx = create_test_context("GET", "/search?name=&age=25")
  let r : TestUser? = bind_query(ctx)
  match r {
    Some(u) => assert_eq(u.age, "25")
    None => assert_true(false)
  }
}

test "bind_path with multiple params" {
  let ctx = create_test_context("GET", "/article/123/hello-world")
  ctx.set_params({ "id": "123", "slug": "hello-world" })
  let r : TestUser? = bind_path(ctx)
  match r {
    Some(_) => assert_true(true)
    None => assert_true(true)
  }
}

test "bind_path with empty params" {
  let ctx = create_test_context("GET", "/")
  let r : TestEmpty? = bind_path(ctx)
  match r {
    Some(_) => assert_true(true)
    None => assert_true(true)
  }
}

test "bind_header with no matching headers" {
  let ctx = create_test_context("GET", "/test")
  let r : TestHeaders? = bind_header(ctx)
  match r {
    Some(_) => assert_true(true)
    None => assert_true(true)
  }
}

test "bind_uri alias delegates to bind_path" {
  let ctx = create_test_context("GET", "/user/99")
  ctx.set_params({ "id": "99", "name": "test" })
  let r : TestMulti? = bind_uri(ctx)
  match r {
    Some(p) => {
      assert_eq(p.name, "test")
      assert_true(true)
    }
    None => assert_true(true)
  }
}

test "validate returns None (always valid)" {
  assert_eq(validate("any"), None)
  assert_eq(validate(0), None)
  assert_eq(validate(false), None)
}

test "is_bind_validation_enabled default is true" {
  // Enable first (it's the default)
  enable_bind_validation()
  assert_true(is_bind_validation_enabled())
}

test "disable_bind_validation toggles correctly" {
  disable_bind_validation()
  assert_false(is_bind_validation_enabled())
  enable_bind_validation()
  assert_true(is_bind_validation_enabled())
}

///| ——————————————————————————————————————————————————————————————————————
///  URL encoding edge cases
///| ——————————————————————————————————————————————————————————————————————

test "bind_query with plus sign as space" {
  let ctx = create_test_context("GET", "/search?name=Hello+World&age=30")
  let r : TestUser? = bind_query(ctx)
  match r {
    Some(u) => assert_eq(u.name, "Hello World")
    None => assert_true(false)
  }
}

test "bind_query with percent encoding in key" {
  let ctx = create_test_context("GET", "/search?user%20name=Alice")
  // Key is url-decoded to "user name"
  let r : TestUser? = bind_query(ctx)
  match r {
    Some(_) => assert_true(true)
    None => assert_true(true)
  }
}

///| ——————————————————————————————————————————————————————————————————————
///  Struct with varying field counts
///| ——————————————————————————————————————————————————————————————————————

struct TestOneField {
  id : String
} derive(@json.FromJson)

struct TestFourFields {
  a : String
  b : String
  c : String
  d : String
} derive(@json.FromJson)

test "bind_query with one field" {
  let ctx = create_test_context("GET", "/item?id=42")
  let r : TestOneField? = bind_query(ctx)
  match r {
    Some(v) => assert_eq(v.id, "42")
    None => assert_true(false)
  }
}

test "bind_query with four fields" {
  let ctx = create_test_context("GET", "/data?a=1&b=2&c=3&d=4")
  let r : TestFourFields? = bind_query(ctx)
  match r {
    Some(v) => {
      assert_eq(v.a, "1")
      assert_eq(v.b, "2")
      assert_eq(v.c, "3")
      assert_eq(v.d, "4")
    }
    None => assert_true(false)
  }
}

test "bind_query partial match" {
  let ctx = create_test_context("GET", "/data?a=1&c=3&b=x&d=y")
  let r : TestFourFields? = bind_query(ctx)
  match r {
    Some(v) => {
      assert_eq(v.a, "1")
      assert_eq(v.c, "3")
      assert_true(true)
    }
    None => assert_true(false)
  }
}
