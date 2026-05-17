///|
priv struct ExprParser {
  text : String
  mut pos : Int
  line : Int
  diagnostics : Array[Diagnostic]
}

///|
fn ExprParser::new(
  text : String,
  line : Int,
  diagnostics : Array[Diagnostic],
) -> ExprParser {
  { text, pos: 0, line, diagnostics }
}

///|
fn ExprParser::at_end(self : ExprParser) -> Bool {
  self.pos >= self.text.length()
}

///|
fn ExprParser::peek(self : ExprParser) -> Char? {
  if self.at_end() {
    None
  } else {
    self.text.get_char(self.pos)
  }
}

///|
fn ExprParser::advance(self : ExprParser) -> Char? {
  match self.peek() {
    Some(c) => {
      self.pos += c.utf16_len()
      Some(c)
    }
    None => None
  }
}

///|
fn ExprParser::skip_ws(self : ExprParser) -> Unit {
  while !self.at_end() {
    match self.peek() {
      Some(c) if c.is_ascii_whitespace() => ignore(self.advance())
      _ => break
    }
  }
}

///|
fn ExprParser::consume_char(self : ExprParser, expected : Char) -> Bool {
  self.skip_ws()
  match self.peek() {
    Some(c) if c == expected => {
      ignore(self.advance())
      true
    }
    _ => false
  }
}

///|
fn ExprParser::starts_with_at(self : ExprParser, needle : String) -> Bool {
  if self.pos + needle.length() > self.text.length() {
    false
  } else {
    self.text.sub(start=self.pos, end=self.pos + needle.length()).to_owned() ==
    needle
  }
}

///|
fn ExprParser::consume_op(self : ExprParser, op : String) -> Bool {
  self.skip_ws()
  if self.starts_with_at(op) {
    self.pos += op.length()
    true
  } else {
    false
  }
}

///|
fn is_ident_start(c : Char) -> Bool {
  c.is_ascii_alphabetic() || c == '_'
}

///|
fn is_ident_part(c : Char) -> Bool {
  is_ident_start(c) || c.is_ascii_digit() || c == '-'
}

///|
fn ExprParser::parse_identifier(self : ExprParser) -> String? {
  self.skip_ws()
  let start = self.pos
  match self.peek() {
    Some(c) if is_ident_start(c) => {
      ignore(self.advance())
      while !self.at_end() {
        match self.peek() {
          Some(c) if is_ident_part(c) => ignore(self.advance())
          _ => break
        }
      }
      Some(self.text.sub(start~, end=self.pos).to_owned())
    }
    _ => None
  }
}

///|
fn ExprParser::parse_number(self : ExprParser) -> Expr {
  let start = self.pos
  while !self.at_end() {
    match self.peek() {
      Some(c) if c.is_ascii_digit() => ignore(self.advance())
      _ => break
    }
  }
  if self.consume_char('.') {
    while !self.at_end() {
      match self.peek() {
        Some(c) if c.is_ascii_digit() => ignore(self.advance())
        _ => break
      }
    }
  }
  Expr::Number(self.text.sub(start~, end=self.pos).to_owned())
}

///|
fn ExprParser::parse_string(self : ExprParser) -> Expr {
  ignore(self.consume_char('"'))
  let builder = StringBuilder::new()
  let mut closed = false
  while !self.at_end() {
    match self.advance() {
      Some('"') => {
        closed = true
        break
      }
      Some('\\') =>
        match self.advance() {
          Some('n') => builder.write_char('\n')
          Some('t') => builder.write_char('\t')
          Some('"') => builder.write_char('"')
          Some('\\') => builder.write_char('\\')
          Some(c) => builder.write_char(c)
          None => ()
        }
      Some(c) => builder.write_char(c)
      None => ()
    }
  }
  if !closed {
    self.diagnostics.push(
      diagnostic("parse-string", "unterminated string literal", line=self.line),
    )
  }
  Expr::String(builder.to_string())
}

///|
fn ExprParser::parse_array(self : ExprParser) -> Expr {
  ignore(self.consume_char('['))
  let items : Array[Expr] = []
  self.skip_ws()
  if self.consume_char(']') {
    return Expr::Array(items)
  }
  while !self.at_end() {
    items.push(self.parse_expr())
    self.skip_ws()
    if self.consume_char(']') {
      break
    }
    if !self.consume_char(',') {
      self.diagnostics.push(
        diagnostic("parse-array", "expected ',' or ']'", line=self.line),
      )
      break
    }
  }
  Expr::Array(items)
}

///|
fn ExprParser::parse_object(self : ExprParser) -> Expr {
  ignore(self.consume_char('{'))
  let fields : Array[ObjectField] = []
  self.skip_ws()
  if self.consume_char('}') {
    return Expr::Object(fields)
  }
  while !self.at_end() {
    let key = match self.peek() {
      Some('"') =>
        match self.parse_string() {
          Expr::String(value) => value
          _ => ""
        }
      _ =>
        match self.parse_identifier() {
          Some(name) => name
          None => {
            self.diagnostics.push(
              diagnostic("parse-object", "expected object key", line=self.line),
            )
            ""
          }
        }
    }
    if !self.consume_char(':') {
      self.diagnostics.push(
        diagnostic(
          "parse-object",
          "expected ':' after object key",
          line=self.line,
          target=key,
        ),
      )
      break
    }
    fields.push({ key, value: self.parse_expr() })
    self.skip_ws()
    if self.consume_char('}') {
      break
    }
    if !self.consume_char(',') {
      self.diagnostics.push(
        diagnostic("parse-object", "expected ',' or '}'", line=self.line),
      )
      break
    }
  }
  Expr::Object(fields)
}

///|
fn ExprParser::parse_arguments(self : ExprParser) -> Array[Argument] {
  let args : Array[Argument] = []
  ignore(self.consume_char('('))
  self.skip_ws()
  if self.consume_char(')') {
    return args
  }
  while !self.at_end() {
    let saved = self.pos
    let maybe_name = self.parse_identifier()
    match maybe_name {
      Some(name) if self.consume_char(':') || self.consume_char('=') =>
        args.push({ name: Some(name), value: self.parse_expr() })
      _ => {
        self.pos = saved
        args.push({ name: None, value: self.parse_expr() })
      }
    }
    self.skip_ws()
    if self.consume_char(')') {
      break
    }
    if !self.consume_char(',') {
      self.diagnostics.push(
        diagnostic("parse-call", "expected ',' or ')'", line=self.line),
      )
      break
    }
  }
  args
}

///|
fn ExprParser::parse_primary(self : ExprParser) -> Expr {
  self.skip_ws()
  match self.peek() {
    Some('"') => self.parse_string()
    Some('[') => self.parse_array()
    Some('{') => self.parse_object()
    Some('(') => {
      ignore(self.consume_char('('))
      let expr = self.parse_expr()
      ignore(self.consume_char(')'))
      expr
    }
    Some('$') => {
      ignore(self.advance())
      match self.parse_identifier() {
        Some(name) => Expr::StateRef(name)
        None => {
          self.diagnostics.push(
            diagnostic("parse-state", "expected state name", line=self.line),
          )
          Expr::Null
        }
      }
    }
    Some('@') => {
      ignore(self.advance())
      let name = self.parse_identifier().unwrap_or("")
      let args = if self.consume_char('(') {
        self.pos -= 1
        self.parse_arguments()
      } else {
        []
      }
      Expr::Builtin(name, args)
    }
    Some(c) if c.is_ascii_digit() => self.parse_number()
    Some(c) if is_ident_start(c) => {
      let name = self.parse_identifier().unwrap_or("")
      if name == "true" {
        Expr::Bool(true)
      } else if name == "false" {
        Expr::Bool(false)
      } else if name == "null" {
        Expr::Null
      } else if self.consume_char('(') {
        self.pos -= 1
        Expr::Call(name, self.parse_arguments())
      } else {
        Expr::Reference(name)
      }
    }
    _ => {
      self.diagnostics.push(
        diagnostic("parse-expr", "expected expression", line=self.line),
      )
      Expr::Null
    }
  }
}

///|
fn ExprParser::parse_postfix(self : ExprParser) -> Expr {
  let mut expr = self.parse_primary()
  while true {
    self.skip_ws()
    if self.consume_char('.') {
      match self.parse_identifier() {
        Some(name) => expr = Expr::Member(expr, name)
        None => {
          self.diagnostics.push(
            diagnostic("parse-member", "expected member name", line=self.line),
          )
          break
        }
      }
    } else {
      break
    }
  }
  expr
}

///|
fn ExprParser::parse_unary(self : ExprParser) -> Expr {
  if self.consume_op("!") {
    Expr::Unary("!", self.parse_unary())
  } else if self.consume_op("-") {
    Expr::Unary("-", self.parse_unary())
  } else {
    self.parse_postfix()
  }
}

///|
fn ExprParser::parse_factor(self : ExprParser) -> Expr {
  let mut expr = self.parse_unary()
  while true {
    if self.consume_op("*") {
      expr = Expr::Binary("*", expr, self.parse_unary())
    } else if self.consume_op("/") {
      expr = Expr::Binary("/", expr, self.parse_unary())
    } else {
      break
    }
  }
  expr
}

///|
fn ExprParser::parse_add(self : ExprParser) -> Expr {
  let mut expr = self.parse_factor()
  while true {
    if self.consume_op("+") {
      expr = Expr::Binary("+", expr, self.parse_factor())
    } else if self.consume_op("-") {
      expr = Expr::Binary("-", expr, self.parse_factor())
    } else {
      break
    }
  }
  expr
}

///|
fn ExprParser::parse_compare(self : ExprParser) -> Expr {
  let mut expr = self.parse_add()
  while true {
    if self.consume_op("==") {
      expr = Expr::Binary("==", expr, self.parse_add())
    } else if self.consume_op("!=") {
      expr = Expr::Binary("!=", expr, self.parse_add())
    } else if self.consume_op(">=") {
      expr = Expr::Binary(">=", expr, self.parse_add())
    } else if self.consume_op("<=") {
      expr = Expr::Binary("<=", expr, self.parse_add())
    } else if self.consume_op(">") {
      expr = Expr::Binary(">", expr, self.parse_add())
    } else if self.consume_op("<") {
      expr = Expr::Binary("<", expr, self.parse_add())
    } else {
      break
    }
  }
  expr
}

///|
fn ExprParser::parse_and(self : ExprParser) -> Expr {
  let mut expr = self.parse_compare()
  while self.consume_op("&&") {
    expr = Expr::Binary("&&", expr, self.parse_compare())
  }
  expr
}

///|
fn ExprParser::parse_or(self : ExprParser) -> Expr {
  let mut expr = self.parse_and()
  while self.consume_op("||") {
    expr = Expr::Binary("||", expr, self.parse_and())
  }
  expr
}

///|
fn ExprParser::parse_expr(self : ExprParser) -> Expr {
  let mut expr = self.parse_or()
  if self.consume_char('?') {
    let truthy = self.parse_expr()
    if !self.consume_char(':') {
      self.diagnostics.push(
        diagnostic("parse-ternary", "expected ':'", line=self.line),
      )
    }
    expr = Expr::Ternary(expr, truthy, self.parse_expr())
  }
  expr
}

///|
fn strip_inline_comment(line : String) -> String {
  let mut quote = false
  let mut escape = false
  let mut index = 0
  for c in line {
    if escape {
      escape = false
    } else if c == '\\' {
      escape = true
    } else if c == '"' {
      quote = !quote
    } else if !quote && c == '/' {
      match line.get_char(index + 1) {
        Some('/') => return line.sub(start=0, end=index).to_owned()
        _ => ()
      }
    }
    index += c.utf16_len()
  }
  line
}

///|
fn parse_statement(
  line : String,
  line_no : Int,
  diagnostics : Array[Diagnostic],
) -> Statement? {
  let trimmed = strip_inline_comment(line).trim().to_owned()
  if trimmed == "" {
    return None
  }
  match trimmed.split_once("=") {
    Some((left_view, right_view)) => {
      let left = left_view.to_owned().trim().to_owned()
      let right = right_view.to_owned().trim().to_owned()
      let is_state = left.has_prefix("$")
      let name = if is_state { left.sub(start=1).to_owned() } else { left }
      if name == "" {
        diagnostics.push(
          diagnostic("parse-statement", "missing statement name", line=line_no),
        )
      }
      let parser = ExprParser::new(right, line_no, diagnostics)
      let expr = parser.parse_expr()
      parser.skip_ws()
      if !parser.at_end() {
        diagnostics.push(
          diagnostic(
            "parse-trailing",
            "unexpected trailing input",
            line=line_no,
            target=parser.text.sub(start=parser.pos).to_owned(),
          ),
        )
      }
      Some({ name, is_state, expr, line: line_no })
    }
    None => {
      diagnostics.push(
        diagnostic(
          "parse-statement",
          "expected '<name> = <expression>'",
          line=line_no,
        ),
      )
      None
    }
  }
}

///|
pub fn parse(
  input : String,
  schema? : @schema.ComponentLibrary = @schema.default_library(),
) -> ParseResult {
  ignore(schema)
  let diagnostics : Array[Diagnostic] = []
  let statements : Array[Statement] = []
  let mut line_no = 1
  let mut entry : String? = None
  for line_view in input.split("\n") {
    match parse_statement(line_view.to_owned(), line_no, diagnostics) {
      Some(stmt) => {
        if !stmt.is_state && entry is None {
          entry = Some(stmt.name)
        }
        statements.push(stmt)
      }
      None => ()
    }
    line_no += 1
  }
  { program: { statements, entry }, diagnostics }
}

///|
pub struct StreamingParser {
  mut buffer : String
  schema : @schema.ComponentLibrary
} derive(Debug)

///|
pub fn StreamingParser::new(
  schema? : @schema.ComponentLibrary = @schema.default_library(),
) -> StreamingParser {
  { buffer: "", schema }
}

///|
pub fn StreamingParser::push(self : StreamingParser, chunk : String) -> Unit {
  self.buffer = self.buffer + chunk
}

///|
pub fn StreamingParser::get_result(self : StreamingParser) -> ParseResult {
  parse(self.buffer, schema=self.schema)
}
