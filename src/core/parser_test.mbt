///|
test "parse component statements and state declarations" {
  let source =
    #|$count = 0
    #|root = Stack([TextContent("Count " + $count), Button("Reset", @Reset($count))])
  let parsed = parse(source)
  assert_true(parsed.program.entry == Some("root"))
  assert_eq(parsed.program.statements.length(), 2)
  assert_eq(parsed.diagnostics.length(), 0)
}

///|
test "streaming parser matches parse result" {
  let parser = StreamingParser::new()
  parser.push("$name = \"MoonBit\"\n")
  parser.push("root = TextContent(\"Hello \" + $name)")
  let streamed = parser.get_result()
  let source =
    #|$name = "MoonBit"
    #|root = TextContent("Hello " + $name)
  let parsed = parse(source)
  assert_true(streamed.program.entry == parsed.program.entry)
  assert_eq(
    streamed.program.statements.length(),
    parsed.program.statements.length(),
  )
  assert_eq(streamed.diagnostics.length(), 0)
}

///|
test "validation diagnostics are stable" {
  let parsed = parse("root = TextContent()")
  let result = evaluate(parsed)
  inspect(
    diagnostics_summary(result.diagnostics),
    content="missing-required:TextContent.content:missing required prop",
  )
}
