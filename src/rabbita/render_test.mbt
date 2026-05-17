///|
test "render static Rabbita-compatible HTML string" {
  let source =
    #|root = Stack([TextContent("Hello"), Button("OK")])
  let parsed = @core.parse(source)
  inspect(
    render_static_string(parsed),
    content="<div class=\"openui-stack\"><p>Hello</p><button class=\"openui-button\">OK</button></div>",
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
