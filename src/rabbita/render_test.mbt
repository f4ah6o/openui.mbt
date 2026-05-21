///|
test "render static Rabbita-compatible HTML string" {
  let source =
    #|root = Stack([TextContent("Hello"), Button("OK")])
  let parsed = @core.parse(source)
  inspect(
    render_static_string(parsed),
    content="<div class=\"openui-stack openui-stack-vertical\"><p>Hello</p><button class=\"openui-button\">OK</button></div>",
  )
}

///|
test "render state-backed input" {
  let source =
    #|$name = "Rabbita"
    #|root = FormControl("Name", Input(value=$name))
  let parsed = @core.parse(source)
  inspect(
    render_static_string(parsed),
    content="<label class=\"openui-form-control\"><span class=\"openui-form-label\">Name</span><input value=\"Rabbita\"></label>",
  )
}

///|
test "render static string mirrors component-specific rendering" {
  let heading =
    #|root = TextContent("Title", variant="h2")
  inspect(render_static_string(@core.parse(heading)), content="<h2>Title</h2>")
  let stack =
    #|root = Stack([TextContent("A")], direction="horizontal")
  inspect(
    render_static_string(@core.parse(stack)),
    content="<div class=\"openui-stack openui-stack-horizontal\"><p>A</p></div>",
  )
  let card =
    #|root = Card([TextContent("Body")], title="Card title")
  inspect(
    render_static_string(@core.parse(card)),
    content="<div class=\"openui-card\"><h2 class=\"openui-card-title\">Card title</h2><p>Body</p></div>",
  )
  let button =
    #|root = Button("Save", variant="primary")
  inspect(
    render_static_string(@core.parse(button)),
    content="<button class=\"openui-button openui-button-primary\">Save</button>",
  )
}

///|
test "render static string supports nontrivial components" {
  let select =
    #|root = Select(value="B", options=["A", "B"])
  inspect(
    render_static_string(@core.parse(select)),
    content="<select><option value=\"A\">A</option><option value=\"B\" selected=\"true\">B</option></select>",
  )
  let buttons =
    #|root = Buttons([Button("One"), Button("Two")])
  inspect(
    render_static_string(@core.parse(buttons)),
    content="<div class=\"openui-buttons\"><button class=\"openui-button\">One</button><button class=\"openui-button\">Two</button></div>",
  )
  let tabs =
    #|root = Tabs([TextContent("Tab")])
  inspect(
    render_static_string(@core.parse(tabs)),
    content="<div class=\"openui-tabs\"><p>Tab</p></div>",
  )
  let table =
    #|root = Table(["name"], [{name: "Ada"}])
  inspect(
    render_static_string(@core.parse(table)),
    content="<table><thead><tr><th>name</th></tr></thead><tbody><tr><td>Ada</td></tr></tbody></table>",
  )
  let chart =
    #|root = BarChart(["A", "B"])
  inspect(
    render_static_string(@core.parse(chart)),
    content="<div class=\"openui-bar-chart\"><h3>BarChart</h3><ul><li>A</li><li>B</li></ul></div>",
  )
}
