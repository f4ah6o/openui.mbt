///|
fn prop(node : @core.ComponentNode, name : String) -> @core.Value {
  node.props.get(name).unwrap_or(@core.VNull)
}

///|
fn text(value : @core.Value) -> String {
  value.to_text()
}

///|
fn children_from_value(value : @core.Value) -> Array[@html.Html] {
  match value {
    @core.VArray(items) => items.map(render_value)
    @core.VElement(_) => [render_value(value)]
    @core.VString(s) => [@html.text(s)]
    @core.VNull => []
    other => [@html.text(other.to_text())]
  }
}

///|
fn render_text_content(node : @core.ComponentNode) -> @html.Html {
  match text(prop(node, "variant")) {
    "h1" => @html.h1(text(prop(node, "content")))
    "h2" => @html.h2(text(prop(node, "content")))
    "h3" => @html.h3(text(prop(node, "content")))
    _ => @html.p(text(prop(node, "content")))
  }
}

///|
fn render_stack(node : @core.ComponentNode) -> @html.Html {
  let direction = text(prop(node, "direction"))
  let gap = text(prop(node, "gap"))
  let class_name = if direction == "horizontal" {
    "openui-stack openui-stack-horizontal"
  } else {
    "openui-stack openui-stack-vertical"
  }
  let style = if gap == "" { [] } else { ["gap: " + gap] }
  @html.div(
    style~,
    class=class_name,
    children_from_value(prop(node, "children")),
  )
}

///|
fn render_card(node : @core.ComponentNode) -> @html.Html {
  let parts : Array[@html.Html] = []
  let title = text(prop(node, "title"))
  if title != "" {
    parts.push(@html.h2(class="openui-card-title", title))
  }
  parts.append(children_from_value(prop(node, "children")))
  @html.div(class="openui-card", parts)
}

///|
fn render_input(node : @core.ComponentNode) -> @html.Html {
  @html.input(
    input_type=@html.Text,
    value=text(prop(node, "value")),
    placeholder=text(prop(node, "placeholder")),
    "",
  )
}

///|
fn render_select(node : @core.ComponentNode) -> @html.Html {
  let current = text(prop(node, "value"))
  let options : Array[@html.Html] = []
  match prop(node, "options") {
    @core.VArray(items) =>
      for item in items {
        let value = item.to_text()
        options.push(@html.option(value~, selected=value == current, value))
      }
    _ => ()
  }
  @html.select(options)
}

///|
fn render_button(node : @core.ComponentNode) -> @html.Html {
  let variant = text(prop(node, "variant"))
  let class_name = if variant == "" {
    "openui-button"
  } else {
    "openui-button openui-button-" + variant
  }
  @html.button(class=class_name, text(prop(node, "label")))
}

///|
fn render_buttons(node : @core.ComponentNode) -> @html.Html {
  @html.div(class="openui-buttons", children_from_value(prop(node, "buttons")))
}

///|
fn render_form_control(node : @core.ComponentNode) -> @html.Html {
  @html.label(class="openui-form-control", [
    @html.span(class="openui-form-label", text(prop(node, "label"))),
    render_value(prop(node, "control")),
  ])
}

///|
fn render_table(node : @core.ComponentNode) -> @html.Html {
  let headers : Array[@html.Html] = []
  match prop(node, "columns") {
    @core.VArray(cols) =>
      for col in cols {
        headers.push(@html.th(col.to_text()))
      }
    _ => ()
  }
  let rows : Array[@html.Html] = []
  match prop(node, "rows") {
    @core.VArray(items) =>
      for row in items {
        let cells : Array[@html.Html] = []
        match row {
          @core.VObject(fields) =>
            match prop(node, "columns") {
              @core.VArray(cols) =>
                for col in cols {
                  cells.push(
                    @html.td(
                      fields.get(col.to_text()).unwrap_or(@core.VNull).to_text(),
                    ),
                  )
                }
              _ => ()
            }
          other => cells.push(@html.td(other.to_text()))
        }
        rows.push(@html.tr(cells))
      }
    _ => ()
  }
  @html.table([@html.thead(@html.tr(headers)), @html.tbody(rows)])
}

///|
fn render_chart(node : @core.ComponentNode) -> @html.Html {
  let rows : Array[@html.Html] = []
  match prop(node, "data") {
    @core.VArray(items) =>
      for item in items {
        rows.push(@html.li(item.to_text()))
      }
    _ => ()
  }
  @html.div(class="openui-bar-chart", [@html.h3("BarChart"), @html.ul(rows)])
}

///|
fn render_value(value : @core.Value) -> @html.Html {
  match value {
    @core.VElement(node) =>
      match node.name {
        "Stack" => render_stack(node)
        "Card" => render_card(node)
        "TextContent" => render_text_content(node)
        "Form" => @html.form(children_from_value(prop(node, "children")))
        "FormControl" => render_form_control(node)
        "Input" => render_input(node)
        "Select" => render_select(node)
        "Button" => render_button(node)
        "Buttons" => render_buttons(node)
        "Tabs" =>
          @html.div(
            class="openui-tabs",
            children_from_value(prop(node, "tabs")),
          )
        "Table" => render_table(node)
        "BarChart" => render_chart(node)
        other => @html.div(class="openui-unknown", other)
      }
    @core.VArray(items) => @html.fragment(items.map(render_value))
    @core.VNull => @html.nothing
    other => @html.text(other.to_text())
  }
}

///|
pub fn render_to_html(
  parsed : @core.ParseResult,
  library? : @schema.ComponentLibrary = @schema.default_library(),
  state? : @core.RuntimeState,
) -> @html.Html {
  let result = match state {
    Some(state) => @core.evaluate(parsed, library~, state~)
    None => @core.evaluate(parsed, library~)
  }
  render_value(result.root)
}

///|
pub fn render_value_to_html(value : @core.Value) -> @html.Html {
  render_value(value)
}

///|
pub fn render_static_string(
  parsed : @core.ParseResult,
  library? : @schema.ComponentLibrary = @schema.default_library(),
  state? : @core.RuntimeState,
) -> String {
  let result = match state {
    Some(state) => @core.evaluate(parsed, library~, state~)
    None => @core.evaluate(parsed, library~)
  }
  stringify_value(result.root)
}

///|
fn escape_text(value : String) -> String {
  value
  .replace_all(old="&", new="&amp;")
  .replace_all(old="<", new="&lt;")
  .replace_all(old=">", new="&gt;")
  .replace_all(old="\"", new="&quot;")
}

///|
fn tag(name : String, class_name : String, children : Array[String]) -> String {
  let class_attr = if class_name == "" {
    ""
  } else {
    " class=\"" + escape_text(class_name) + "\""
  }
  "<" + name + class_attr + ">" + children.join("") + "</" + name + ">"
}

///|
fn stringify_node(node : @core.ComponentNode) -> String {
  match node.name {
    "TextContent" => tag("p", "", [escape_text(text(prop(node, "content")))])
    "Stack" =>
      tag("div", "openui-stack", stringify_children(prop(node, "children")))
    "Card" =>
      tag("div", "openui-card", stringify_children(prop(node, "children")))
    "Button" =>
      tag("button", "openui-button", [escape_text(text(prop(node, "label")))])
    "Input" =>
      "<input value=\"" + escape_text(text(prop(node, "value"))) + "\">"
    "Form" => tag("form", "", stringify_children(prop(node, "children")))
    "FormControl" =>
      tag("label", "openui-form-control", [
        tag("span", "openui-form-label", [
          escape_text(text(prop(node, "label"))),
        ]),
        stringify_value(prop(node, "control")),
      ])
    other => tag("div", "openui-unknown", [escape_text(other)])
  }
}

///|
fn stringify_children(value : @core.Value) -> Array[String] {
  match value {
    @core.VArray(items) => items.map(stringify_value)
    @core.VElement(_) => [stringify_value(value)]
    @core.VNull => []
    other => [escape_text(other.to_text())]
  }
}

///|
fn stringify_value(value : @core.Value) -> String {
  match value {
    @core.VElement(node) => stringify_node(node)
    @core.VArray(items) => items.map(stringify_value).join("")
    @core.VNull => ""
    other => escape_text(other.to_text())
  }
}
