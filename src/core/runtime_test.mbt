///|
test "evaluate state references and action updates" {
  let source =
    #|$count = 0
    #|root = Button("Inc", @Set($count, "1"))
  let parsed = parse(source)
  let initial = RuntimeState::new(parsed.program)
  inspect(initial.get("count").to_text(), content="0")
  let updated = initial.apply(Set("count", VNumber("1")))
  inspect(updated.get("count").to_text(), content="1")
}

///|
test "evaluate component tree" {
  let source =
    #|$name = "OpenUI"
    #|root = Stack([TextContent("Hello " + $name), Input(value=$name)])
  let parsed = parse(source)
  let result = evaluate(parsed)
  match result.root {
    VElement(node) => {
      inspect(node.name, content="Stack")
      assert_eq(result.diagnostics.length(), 0)
    }
    other => inspect(other.to_text())
  }
}
