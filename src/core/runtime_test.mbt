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

///|
test "numeric expressions keep numeric semantics" {
  let source = "neg = -5\ncmp = 9 > 10\nmul = 3 * 4\nroot = 0.00 ? \"bad\" : \"ok\""
  let parsed = parse(source)
  let result = evaluate({
    program: { statements: parsed.program.statements, entry: Some("root") },
    diagnostics: [],
  })
  match result.root {
    VString(value) => inspect(value, content="ok")
    other => inspect(other.to_text())
  }
  match
    evaluate({
      program: { statements: parsed.program.statements, entry: Some("neg") },
      diagnostics: [],
    }).root {
    VNumber(value) => inspect(value, content="-5")
    other => inspect(other.to_text())
  }
  match
    evaluate({
      program: { statements: parsed.program.statements, entry: Some("cmp") },
      diagnostics: [],
    }).root {
    VBool(value) => inspect(value, content="false")
    other => inspect(other.to_text())
  }
  match
    evaluate({
      program: { statements: parsed.program.statements, entry: Some("mul") },
      diagnostics: [],
    }).root {
    VNumber(value) => inspect(value, content="12")
    other => inspect(other.to_text())
  }
}

///|
test "boolean operators short circuit" {
  let left_false = evaluate(parse("root = false && missing_ref"))
  match left_false.root {
    VBool(value) => inspect(value, content="false")
    other => inspect(other.to_text())
  }
  assert_eq(left_false.diagnostics.length(), 0)
  let left_true = evaluate(parse("root = true || missing_ref"))
  match left_true.root {
    VBool(value) => inspect(value, content="true")
    other => inspect(other.to_text())
  }
  assert_eq(left_true.diagnostics.length(), 0)
}
