///|
/// Path utilities tests — clean_path, split_path, strip_query.

test "clean_path empty string" {
  assert_eq(clean_path(""), "/")
}

test "clean_path root" {
  assert_eq(clean_path("/"), "/")
}

test "clean_path no changes" {
  assert_eq(clean_path("/api/users"), "/api/users")
}

test "clean_path removes duplicate slashes" {
  assert_eq(clean_path("//a//b//c"), "/a/b/c")
}

test "clean_path resolves single dot" {
  assert_eq(clean_path("/a/./b/./c"), "/a/b/c")
}

test "clean_path resolves double dot" {
  assert_eq(clean_path("/a/b/../c"), "/a/c")
}

test "clean_path resolves multiple double dots" {
  assert_eq(clean_path("/a/b/c/../../d"), "/a/d")
}

test "clean_path dot at start" {
  assert_eq(clean_path("./api/users"), "/api/users")
}

test "clean_path double dot beyond root" {
  assert_eq(clean_path("/a/../../b"), "/b")
}

test "clean_path many dots beyond root" {
  assert_eq(clean_path("/../../../etc"), "/etc")
}

test "clean_path trailing dot" {
  assert_eq(clean_path("/api/."), "/api")
}

test "clean_path trailing double dot" {
  assert_eq(clean_path("/api/users/.."), "/api")
}

test "clean_path mixed dots and slashes" {
  assert_eq(clean_path("/./a/./b/.././c/."), "/a/c")
}

test "clean_path only dots" {
  assert_eq(clean_path("./."), "/")
}

test "clean_path with encoded chars preserved" {
  assert_eq(clean_path("/api/hello%20world"), "/api/hello%20world")
}

test "clean_path with special chars" {
  assert_eq(clean_path("/api/v1.0-beta"), "/api/v1.0-beta")
}

///| ——————————————————————————————————————————————————————————————————————
///  split_path tests
///| ——————————————————————————————————————————————————————————————————————

test "split_path root only" {
  let segs = split_path("/")
  assert_eq(segs.length(), 0)
}

test "split_path empty" {
  let segs = split_path("")
  assert_eq(segs.length(), 0)
}

test "split_path single segment" {
  let segs = split_path("/api")
  assert_eq(segs.length(), 1)
  assert_eq(segs[0], "api")
}

test "split_path multiple segments" {
  let segs = split_path("/api/v1/users")
  assert_eq(segs.length(), 3)
  assert_eq(segs[0], "api")
  assert_eq(segs[1], "v1")
  assert_eq(segs[2], "users")
}

test "split_path trailing slash" {
  let segs = split_path("/api/users/")
  assert_eq(segs.length(), 2)
}

test "split_path leading and trailing slashes" {
  let segs = split_path("/a/b/c/")
  assert_eq(segs.length(), 3)
}

test "split_path with query string preserved" {
  // split_path does not strip query, so it would be part of last segment
  let segs = split_path("/api/users?id=1")
  assert_eq(segs.length(), 2)
}

test "split_path deep nesting" {
  let segs = split_path("/a/b/c/d/e/f/g/h")
  assert_eq(segs.length(), 8)
}

test "split_path with hyphens" {
  let segs = split_path("/my-route/user-profile")
  assert_eq(segs.length(), 2)
  assert_eq(segs[1], "user-profile")
}

test "split_path with underscores" {
  let segs = split_path("/api/user_names")
  assert_eq(segs.length(), 2)
  assert_eq(segs[1], "user_names")
}

///| ——————————————————————————————————————————————————————————————————————
///  strip_query tests
///| ——————————————————————————————————————————————————————————————————————

test "strip_query no query" {
  assert_eq(strip_query("/api/users"), "/api/users")
}

test "strip_query single param" {
  assert_eq(strip_query("/api?id=1"), "/api")
}

test "strip_query multiple params" {
  assert_eq(strip_query("/search?q=cat&page=1&size=10"), "/search")
}

test "strip_query question only" {
  assert_eq(strip_query("/api?"), "/api")
}

test "strip_query empty string" {
  assert_eq(strip_query(""), "")
}

test "strip_query root with query" {
  assert_eq(strip_query("/?debug=true"), "/")
}

test "strip_query with URL encoded query" {
  assert_eq(strip_query("/search?q=hello%20world"), "/search")
}

test "strip_query with fragment-like content" {
  // strip_query only looks for ?, so # is part of query
  assert_eq(strip_query("/a?b=1#section"), "/a")
}

///| ——————————————————————————————————————————————————————————————————————
///  Path combination edge cases
///| ——————————————————————————————————————————————————————————————————————

test "clean_path with Chinese characters" {
  let path = clean_path("/api/用户/信息")
  assert_eq(path, "/api/用户/信息")
}

test "clean_path with emoji" {
  let path = clean_path("/api/😀/test")
  assert_eq(path, "/api/😀/test")
}

test "split_path with unicode" {
  let segs = split_path("/api/用户/信息")
  assert_eq(segs.length(), 3)
  assert_eq(segs[1], "用户")
}
