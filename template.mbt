///|
/// HTML template rendering support.
///
/// HTML template rendering with glob/file loading.
/// In MoonBit, template rendering is simplified — HTML templates are plain
/// strings with `{{ .key }}` placeholders replaced via simple string substitution.

///|
/// Template store — maps template name to template string.
pub(all) struct TemplateStore {
  templates : Map[String, String]
  mut delims_left : String
  mut delims_right : String
}

///|
pub fn TemplateStore::new() -> TemplateStore {
  { templates: Map([]), delims_left: "{{", delims_right: "}}" }
}

///|
/// Set template delimiters (default: `{{` and `}}`).
pub fn TemplateStore::set_delims(
  self : TemplateStore,
  left : String,
  right : String,
) -> Unit {
  self.delims_left = left
  self.delims_right = right
}

///|
/// Load a single template from a string.
pub fn TemplateStore::add_template(
  self : TemplateStore,
  name : String,
  content : String,
) -> Unit {
  self.templates.set(name, content)
}

///|
/// Load templates from a glob pattern. Reads all matching files.
pub async fn TemplateStore::load_glob(
  self : TemplateStore,
  pattern : String,
) -> Unit {
  // Simple glob: just load a single file or directory listing
  try {
    // If pattern ends with *, load all files in directory
    if pattern.has_suffix("*") {
      let dir = pattern[:pattern.length() - 1].to_owned()
      let files = @fs.readdir(dir)
      for file in files {
        if file.has_suffix(".html") || file.has_suffix(".tmpl") {
          let content = @fs.read_file(dir + "/" + file).text()
          let name = file
            .replace_all(old=".html", new="")
            .replace_all(old=".tmpl", new="")
          self.templates.set(name, content)
        }
      }
    } else {
      // Single file
      let content = @fs.read_file(pattern).text()
      // Extract filename as template name
      let name = match pattern.rev_find("/") {
        Some(pos) => pattern[pos + 1:].to_owned()
        None => pattern
      }
      let name = name
        .replace_all(old=".html", new="")
        .replace_all(old=".tmpl", new="")
      self.templates.set(name, content)
    }
  } catch {
    _ => ()
  }
}

///|
/// Load templates from a list of file paths.
pub async fn TemplateStore::load_files(
  self : TemplateStore,
  files : Array[String],
) -> Unit {
  for file in files {
    try {
      let content = @fs.read_file(file).text()
      let name = match file.rev_find("/") {
        Some(pos) => file[pos + 1:].to_owned()
        None => file
      }
      let name = name
        .replace_all(old=".html", new="")
        .replace_all(old=".tmpl", new="")
      self.templates.set(name, content)
    } catch {
      _ => ()
    }
  }
}

///|
/// Render a template with data. Replaces `{{ .key }}` placeholders.
pub fn TemplateStore::render(
  self : TemplateStore,
  name : String,
  data : Map[String, String],
) -> String? {
  match self.templates.get(name) {
    Some(tmpl) => {
      let mut result = tmpl
      for key, value in data {
        let placeholder = self.delims_left + " ." + key + " " + self.delims_right
        result = result.replace_all(old=placeholder, new=value)
        // Also support {{ .key }} without spaces
        let placeholder2 = self.delims_left + "." + key + self.delims_right
        result = result.replace_all(old=placeholder2, new=value)
      }
      Some(result)
    }
    None => None
  }
}

///|
/// Global template store for engine-wide template access.
let global_templates : TemplateStore = TemplateStore::new()

///|
/// Set the HTML template delimiters.
pub fn set_template_delims(left : String, right : String) -> Unit {
  global_templates.set_delims(left, right)
}

///|
/// Load HTML templates from a glob pattern.
pub async fn load_html_glob(pattern : String) -> Unit {
  global_templates.load_glob(pattern)
}

///|
/// Load HTML templates from file paths.
pub async fn load_html_files(files : Array[String]) -> Unit {
  global_templates.load_files(files)
}

///|
/// Set a single HTML template by name and content.
pub fn set_html_template(name : String, content : String) -> Unit {
  global_templates.add_template(name, content)
}

///|
/// Render an HTML template response.
pub async fn Context::html_template(
  self : Context,
  code : Int,
  name : String,
  data : Map[String, String],
) -> Unit {
  match global_templates.render(name, data) {
    Some(html) => self.html(code, html)
    None => self.abort_with_status(500, "Template not found: " + name)
  }
}
