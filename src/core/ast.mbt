///|
pub(all) struct Argument {
  name : String?
  value : Expr
} derive(Debug, Eq)

///|
pub(all) struct ObjectField {
  key : String
  value : Expr
} derive(Debug, Eq)

///|
pub(all) enum Expr {
  Null
  Bool(Bool)
  Number(String)
  String(String)
  Array(Array[Expr])
  Object(Array[ObjectField])
  Reference(String)
  StateRef(String)
  Member(Expr, String)
  Call(String, Array[Argument])
  Builtin(String, Array[Argument])
  Unary(String, Expr)
  Binary(String, Expr, Expr)
  Ternary(Expr, Expr, Expr)
} derive(Debug, Eq)

///|
pub(all) struct Statement {
  name : String
  is_state : Bool
  expr : Expr
  line : Int
} derive(Debug, Eq)

///|
pub(all) struct Program {
  statements : Array[Statement]
  entry : String?
} derive(Debug, Eq)

///|
pub(all) struct Diagnostic {
  code : String
  message : String
  line : Int
  target : String
} derive(Debug, Eq)

///|
pub(all) struct ParseResult {
  program : Program
  diagnostics : Array[Diagnostic]
} derive(Debug, Eq)

///|
pub fn diagnostic(
  code : String,
  message : String,
  line? : Int = 0,
  target? : String = "",
) -> Diagnostic {
  { code, message, line, target }
}

///|
pub fn Diagnostic::summary(self : Diagnostic) -> String {
  self.code + ":" + self.target + ":" + self.message
}

///|
pub fn diagnostics_summary(diagnostics : Array[Diagnostic]) -> String {
  diagnostics.map(d => d.summary()).join("\n")
}
