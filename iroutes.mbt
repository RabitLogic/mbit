///|
/// Route registration interface — common API for Engine and Group.
///
/// Defines the shared route registration methods that both
/// `Engine` and `Group` provide.

///|
/// IRoutes defines the common route registration methods.
pub trait IRoutes {
  get(String, Array[Handler]) -> Unit
  post(String, Array[Handler]) -> Unit
  put(String, Array[Handler]) -> Unit
  del(String, Array[Handler]) -> Unit
  patch(String, Array[Handler]) -> Unit
  head(String, Array[Handler]) -> Unit
  options(String, Array[Handler]) -> Unit
  any(String, Array[Handler]) -> Unit
  handle(Array[Method], String, Array[Handler]) -> Unit
  use_mw(Handler) -> Unit
}
