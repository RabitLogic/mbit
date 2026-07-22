/// mbit full-feature demo — tests ALL framework capabilities.
/// Run: moon run demo --target native

///| ——— Data types for binding ———

struct User { name : String } derive(@json.FromJson)
struct LoginReq { username : String; password : String } derive(@json.FromJson)

///| ——— Root ———

async fn h_root(ctx : @RabitLogic/mbit.Context) -> Unit {
  ctx.json(200, Json::object(@RabitLogic/mbit.h([("service",Json::string("mbit-demo")),("version",Json::string("0.1.0"))])))
}

///| ——— Health / Hello ———

async fn h_health(ctx : @RabitLogic/mbit.Context) -> Unit {
  ctx.json(200, Json::object(@RabitLogic/mbit.h([("status",Json::string("ok"))])))
}
async fn h_hello(ctx : @RabitLogic/mbit.Context) -> Unit { ctx.string(200, "Hello, mbit!") }
async fn h_hello_name(ctx : @RabitLogic/mbit.Context) -> Unit {
  ctx.string(200, "Hello, " + ctx.param_default("name","world") + "!")
}

///| ——— Query ———

async fn h_search(ctx : @RabitLogic/mbit.Context) -> Unit {
  ctx.json(200, Json::object(@RabitLogic/mbit.h([("q",Json::string(ctx.query_default("q",""))),("page",Json::string(ctx.query_default("page","1")))])))
}
async fn h_query_all(ctx : @RabitLogic/mbit.Context) -> Unit {
  let map = ctx.query_map()
  let items : Array[(String,Json)] = []
  for k, v in map { items.push((k, Json::string(v))) }
  ctx.json(200, Json::object(@RabitLogic/mbit.h(items)))
}

///| ——— Echo ———

async fn h_echo(ctx : @RabitLogic/mbit.Context) -> Unit {
  match ctx.body_json() {
    Some(j) => ctx.json(200, j)
    None => ctx.json(400, Json::object(@RabitLogic/mbit.h([("error",Json::string("bad JSON"))])))
  }
}

///| ——— CRUD ———

async fn h_create_user(ctx : @RabitLogic/mbit.Context) -> Unit {
  let u : User? = @RabitLogic/mbit.bind_json(ctx)
  match u {
    Some(user) => ctx.json(201, Json::object(@RabitLogic/mbit.h([("msg",Json::string("Created")),("name",Json::string(user.name))])))
    None => ctx.json(400, Json::object(@RabitLogic/mbit.h([("error",Json::string("bad user"))])))
  }
}
async fn h_put_user(ctx : @RabitLogic/mbit.Context) -> Unit {
  let id = ctx.param_default("id","0")
  match ctx.body_json() {
    Some(j) => ctx.json(200, Json::object(@RabitLogic/mbit.h([("msg",Json::string("Updated "+id)),("data",j)])))
    None => ctx.json(400, Json::object(@RabitLogic/mbit.h([("error",Json::string("bad JSON"))])))
  }
}
async fn h_delete_user(ctx : @RabitLogic/mbit.Context) -> Unit {
  ctx.json(200, Json::object(@RabitLogic/mbit.h([("msg",Json::string("Deleted "+ctx.param_default("id","0")))])))
}
async fn h_patch_user(ctx : @RabitLogic/mbit.Context) -> Unit {
  let id = ctx.param_default("id","0")
  match ctx.body_json() {
    Some(j) => ctx.json(200, Json::object(@RabitLogic/mbit.h([("msg",Json::string("Patched "+id)),("data",j)])))
    None => ctx.json(400, Json::object(@RabitLogic/mbit.h([("error",Json::string("bad JSON"))])))
  }
}

///| ——— Login ———

async fn h_login(ctx : @RabitLogic/mbit.Context) -> Unit {
  let r : LoginReq? = @RabitLogic/mbit.bind_json(ctx)
  match r {
    Some(req) => if req.username=="admin" && req.password=="secret" {
      ctx.json(200, Json::object(@RabitLogic/mbit.h([("token",Json::string("demo-token")),("user",Json::string(req.username))])))
    } else { ctx.json(401, Json::object(@RabitLogic/mbit.h([("error",Json::string("bad credentials"))]))) }
    None => ctx.json(400, Json::object(@RabitLogic/mbit.h([("error",Json::string("bad data"))])))
  }
}

///| ——— Validation ———

async fn h_register(ctx : @RabitLogic/mbit.Context) -> Unit {
  match ctx.body_json() {
    Some(json) => {
      let vals : Map[String,String] = Map([])
      match json { Json::Object(m) => for k,v in m { match v { Json::String(s)=>vals.set(k,s); Json::Number(n, ..)=>vals.set(k,n.to_string()); _=>() } }; _ => () }
      let rules = [
        @RabitLogic/mbit.FieldRules::new("username",[@RabitLogic/mbit.Required,@RabitLogic/mbit.Min(3),@RabitLogic/mbit.Max(20)]),
        @RabitLogic/mbit.FieldRules::new("password",[@RabitLogic/mbit.Required,@RabitLogic/mbit.Min(6)]),
        @RabitLogic/mbit.FieldRules::new("email",[@RabitLogic/mbit.Required,@RabitLogic/mbit.Email]),
      ]
      let errs = @RabitLogic/mbit.validate_map(vals,rules)
      if errs.has_errors() { ctx.json(422, errs.to_json()) } else { ctx.json(201, Json::object(@RabitLogic/mbit.h([("msg",Json::string("OK"))]))) }
    }
    None => ctx.json(400, Json::object(@RabitLogic/mbit.h([("error",Json::string("bad JSON"))])))
  }
}

///| ——— Rendering ———

async fn h_json_list(ctx : @RabitLogic/mbit.Context) -> Unit {
  ctx.json(200, Json::object(@RabitLogic/mbit.h([("items",Json::array([
    Json::object(@RabitLogic/mbit.h([("id",Json::number(1.0)),("name",Json::string("A"))])),
    Json::object(@RabitLogic/mbit.h([("id",Json::number(2.0)),("name",Json::string("B"))])),
  ]))])))
}
async fn h_xml(ctx : @RabitLogic/mbit.Context) -> Unit { ctx.xml(200,Json::object(@RabitLogic/mbit.h([("msg",Json::string("hi"))]))) }
async fn h_yaml(ctx : @RabitLogic/mbit.Context) -> Unit { ctx.yaml(200,Json::object(@RabitLogic/mbit.h([("msg",Json::string("hi"))]))) }
async fn h_html(ctx : @RabitLogic/mbit.Context) -> Unit { ctx.html(200,"<h1>mbit HTML</h1><p>from MoonBit</p>") }
async fn h_redirect(ctx : @RabitLogic/mbit.Context) -> Unit { ctx.redirect(301,"/api/hello") }
async fn h_no_content(ctx : @RabitLogic/mbit.Context) -> Unit { ctx.no_content() }

///| ——— SSE & Stream ———

async fn h_sse(ctx : @RabitLogic/mbit.Context) -> Unit {
  ctx.stream_start(200, "text/event-stream")
  for i=0;i<5;i=i+1 { ctx.sse("msg","#"+i.to_string()); ctx.sse_flush() }
  ctx.sse("done","complete")
  ctx.end_stream()
}
async fn h_stream(ctx : @RabitLogic/mbit.Context) -> Unit {
  ctx.stream(200, "text/plain", async fn(w : async (String) -> Unit) -> Unit { w("chunk-1\n"); w("chunk-2\n"); w("chunk-3\n") })
}

///| ——— Negotiation ———

async fn h_negotiate(ctx : @RabitLogic/mbit.Context) -> Unit {
  let data = @RabitLogic/mbit.h([("msg",Json::string("hello"))])
  match ctx.negotiate_format(["application/json","text/html","text/plain"]) {
    Some("application/json") => ctx.json(200,Json::object(data))
    Some("text/html") => ctx.html(200,"<h1>hello</h1>")
    Some("text/plain") => ctx.string(200,"hello")
    _ => ctx.json(406,Json::object(@RabitLogic/mbit.h([("error",Json::string("not acceptable"))])))
  }
}

///| ——— Context Store ———

async fn h_store_set(ctx : @RabitLogic/mbit.Context) -> Unit { ctx.set("shared",Json::string("stored-value")); ctx.next() }
async fn h_store_get(ctx : @RabitLogic/mbit.Context) -> Unit {
  ctx.json(200,Json::object(@RabitLogic/mbit.h([("value",Json::string(ctx.get_string("shared").unwrap_or("missing")))])))
}

///| ——— Files ———

async fn h_file(ctx : @RabitLogic/mbit.Context) -> Unit { ctx.file_attachment("demo.txt") }
async fn h_files_wc(ctx : @RabitLogic/mbit.Context) -> Unit {
  ctx.json(200,Json::object(@RabitLogic/mbit.h([("file",Json::string(ctx.param_default("filepath","")))])))
}

///| ——— Errors ———

async fn h_403(ctx : @RabitLogic/mbit.Context) -> Unit { ctx.abort_with_status(403,"Access denied") }
async fn h_404(ctx : @RabitLogic/mbit.Context) -> Unit {
  ctx.json(404,Json::object(@RabitLogic/mbit.h([("error",Json::string("Custom 404")),("path",Json::string(ctx.path()))])))
}
async fn h_405(ctx : @RabitLogic/mbit.Context) -> Unit {
  ctx.set_header("Allow","GET,POST"); ctx.json(405,Json::object(@RabitLogic/mbit.h([("error",Json::string("Method Not Allowed"))])))
}
async fn h_options_h(ctx : @RabitLogic/mbit.Context) -> Unit {
  ctx.set_header("Allow","GET,POST,PUT,DELETE,PATCH,OPTIONS,HEAD"); ctx.no_content()
}

///| ——— Main ———

async fn main {
  let app = @RabitLogic/mbit.default()
  // Middleware
  app.use(@RabitLogic/mbit.logger()) |> ignore
  app.use(@RabitLogic/mbit.recovery()) |> ignore
  app.use(@RabitLogic/mbit.cors(@RabitLogic/mbit.CORSConfig::default())) |> ignore
  app.use(@RabitLogic/mbit.request_id()) |> ignore
  app.use(@RabitLogic/mbit.timing()) |> ignore
  // Error handlers
  app.no_route([h_404])
  app.no_method([h_405])

  // Routes
  app.get("/",[h_root]) |> ignore
  app.any("/api/health",[h_health]) |> ignore
  app.head("/api/health",[h_health]) |> ignore
  app.options("/api/health",[h_options_h]) |> ignore
  app.get("/api/hello",[h_hello]) |> ignore
  app.get("/api/hello/:name",[h_hello_name]) |> ignore
  app.get("/api/search",[h_search]) |> ignore
  app.get("/api/query-all",[h_query_all]) |> ignore
  app.post("/api/echo",[h_echo]) |> ignore
  app.post("/api/users",[h_create_user]) |> ignore
  app.get("/api/users/:id",[h_hello_name]) |> ignore
  app.put("/api/users/:id",[h_put_user]) |> ignore
  app.del("/api/users/:id",[h_delete_user]) |> ignore
  app.patch("/api/users/:id",[h_patch_user]) |> ignore
  app.post("/api/login",[h_login]) |> ignore
  app.post("/api/register",[h_register]) |> ignore
  app.get("/api/render/json",[h_json_list]) |> ignore
  app.get("/api/render/xml",[h_xml]) |> ignore
  app.get("/api/render/yaml",[h_yaml]) |> ignore
  app.get("/api/render/html",[h_html]) |> ignore
  app.get("/api/render/redirect",[h_redirect]) |> ignore
  app.get("/api/render/no-content",[h_no_content]) |> ignore
  app.get("/api/sse",[h_sse]) |> ignore
  app.get("/api/stream",[h_stream]) |> ignore
  app.get("/api/negotiate",[h_negotiate]) |> ignore
  app.get("/api/store",[h_store_set,h_store_get]) |> ignore
  app.get("/api/file",[h_file]) |> ignore
  app.get("/api/files/*filepath",[h_files_wc]) |> ignore
  app.get("/api/error/403",[h_403]) |> ignore

  @RabitLogic/mbit.debug_print_listen("http://0.0.0.0:8080")
  app.run("0.0.0.0:8080")
}
