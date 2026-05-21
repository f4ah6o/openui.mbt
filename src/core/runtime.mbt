///|
pub(all) enum Value {
  VNull
  VBool(Bool)
  VNumber(String)
  VString(String)
  VArray(Array[Value])
  VObject(Map[String, Value])
  VElement(ComponentNode)
  VAction(Array[ActionStep])
  VUnsupported(String)
} derive(Debug)

///|
pub(all) struct ComponentNode {
  name : String
  props : Map[String, Value]
} derive(Debug)

///|
pub(all) enum ActionStep {
  Set(String, Value)
  Reset(String)
  Unsupported(String)
} derive(Debug)

///|
pub(all) struct RuntimeState {
  defaults : Map[String, Value]
  values : Map[String, Value]
} derive(Debug)

///|
priv struct EvalContext {
  library : @schema.ComponentLibrary
  diagnostics : Array[Diagnostic]
  state : RuntimeState
  defs : Map[String, Statement]
  stack : Array[String]
}

///|
pub fn Value::to_text(self : Value) -> String {
  match self {
    VNull => ""
    VBool(v) => if v { "true" } else { "false" }
    VNumber(v) => v
    VString(v) => v
    VArray(_) => "[array]"
    VObject(_) => "[object]"
    VElement(node) => "[component " + node.name + "]"
    VAction(_) => "[action]"
    VUnsupported(message) => "[unsupported " + message + "]"
  }
}

///|
pub fn Value::is_truthy(self : Value) -> Bool {
  match self {
    VNull => false
    VBool(v) => v
    VNumber(v) => parse_number_value(v).unwrap_or(0.0) != 0.0
    VString(v) => v != ""
    VArray(items) => !items.is_empty()
    VObject(fields) => !fields.is_empty()
    VElement(_) | VAction(_) => true
    VUnsupported(_) => false
  }
}

///|
fn parse_number_value(value : String) -> Double? {
  let parsed : Double = @strconv.from_str(value) catch { _ => return None }
  Some(parsed)
}

///|
fn number_binary(
  left : Value,
  right : Value,
  op : (Double, Double) -> Double,
) -> Value? {
  match (left, right) {
    (VNumber(l), VNumber(r)) =>
      match (parse_number_value(l), parse_number_value(r)) {
        (Some(left), Some(right)) => Some(VNumber(op(left, right).to_string()))
        _ => None
      }
    _ => None
  }
}

///|
pub fn RuntimeState::new(program : Program) -> RuntimeState {
  let defaults : Map[String, Value] = {}
  for stmt in program.statements {
    if stmt.is_state {
      defaults[stmt.name] = literal_default(stmt.expr)
    }
  }
  { defaults, values: defaults.copy() }
}

///|
pub fn RuntimeState::get(self : RuntimeState, name : String) -> Value {
  self.values.get(name).unwrap_or(VNull)
}

///|
pub fn RuntimeState::apply(
  self : RuntimeState,
  step : ActionStep,
) -> RuntimeState {
  let next = self.values.copy()
  match step {
    Set(name, value) => next[name] = value
    Reset(name) => next[name] = self.defaults.get(name).unwrap_or(VNull)
    Unsupported(_) => ()
  }
  { defaults: self.defaults.copy(), values: next }
}

///|
pub fn RuntimeState::apply_all(
  self : RuntimeState,
  steps : Array[ActionStep],
) -> RuntimeState {
  let mut state = self
  for step in steps {
    state = state.apply(step)
  }
  state
}

///|
fn literal_default(expr : Expr) -> Value {
  match expr {
    Null => VNull
    Bool(v) => VBool(v)
    Number(v) => VNumber(v)
    String(v) => VString(v)
    Array(items) => VArray(items.map(literal_default))
    Object(fields) => {
      let map : Map[String, Value] = {}
      for field in fields {
        map[field.key] = literal_default(field.value)
      }
      VObject(map)
    }
    _ => VNull
  }
}

///|
fn build_defs(program : Program) -> Map[String, Statement] {
  let defs : Map[String, Statement] = {}
  for stmt in program.statements {
    defs[stmt.name] = stmt
  }
  defs
}

///|
fn EvalContext::new(
  program : Program,
  library : @schema.ComponentLibrary,
  diagnostics : Array[Diagnostic],
  state : RuntimeState,
) -> EvalContext {
  { library, diagnostics, state, defs: build_defs(program), stack: [] }
}

///|
fn EvalContext::eval_ref(self : EvalContext, name : String) -> Value {
  if self.stack.contains(name) {
    self.diagnostics.push(diagnostic("cycle", "cyclic reference", target=name))
    return VNull
  }
  match self.defs.get(name) {
    Some(stmt) => {
      self.stack.push(name)
      let value = self.eval(stmt.expr)
      ignore(self.stack.pop())
      value
    }
    None => {
      self.diagnostics.push(
        diagnostic("unknown-reference", "unknown reference", target=name),
      )
      VNull
    }
  }
}

///|
fn EvalContext::eval_member(
  self : EvalContext,
  base : Value,
  field_name : String,
) -> Value {
  ignore(self)
  match base {
    VObject(fields) => fields.get(field_name).unwrap_or(VNull)
    _ => VNull
  }
}

///|
fn EvalContext::eval(self : EvalContext, expr : Expr) -> Value {
  match expr {
    Null => VNull
    Bool(v) => VBool(v)
    Number(v) => VNumber(v)
    String(v) => VString(v)
    Array(items) => VArray(items.map(item => self.eval(item)))
    Object(fields) => {
      let map : Map[String, Value] = {}
      for field in fields {
        map[field.key] = self.eval(field.value)
      }
      VObject(map)
    }
    Reference(name) => self.eval_ref(name)
    StateRef(name) => self.state.get(name)
    Member(base, field_name) => self.eval_member(self.eval(base), field_name)
    Call(name, args) => self.eval_call(name, args)
    Builtin(name, args) => self.eval_builtin(name, args)
    Unary(op, inner) => self.eval_unary(op, inner)
    Binary(op, left, right) => self.eval_binary(op, left, right)
    Ternary(cond, truthy, falsy) =>
      if self.eval(cond).is_truthy() {
        self.eval(truthy)
      } else {
        self.eval(falsy)
      }
  }
}

///|
fn EvalContext::eval_unary(
  self : EvalContext,
  op : String,
  inner : Expr,
) -> Value {
  let value = self.eval(inner)
  match op {
    "!" => VBool(!value.is_truthy())
    "-" =>
      match value {
        VNumber(raw) =>
          match parse_number_value(raw) {
            Some(number) => VNumber((-number).to_string())
            None => VNumber("-" + raw)
          }
        _ => VUnsupported("-")
      }
    _ => VUnsupported(op)
  }
}

///|
fn EvalContext::eval_binary(
  self : EvalContext,
  op : String,
  left : Expr,
  right : Expr,
) -> Value {
  match op {
    "&&" => {
      let l = self.eval(left)
      if !l.is_truthy() {
        VBool(false)
      } else {
        VBool(self.eval(right).is_truthy())
      }
    }
    "||" => {
      let l = self.eval(left)
      if l.is_truthy() {
        VBool(true)
      } else {
        VBool(self.eval(right).is_truthy())
      }
    }
    _ => {
      let l = self.eval(left)
      let r = self.eval(right)
      match op {
        "+" =>
          match number_binary(l, r, fn(a, b) { a + b }) {
            Some(value) => value
            None => VString(l.to_text() + r.to_text())
          }
        "-" =>
          match number_binary(l, r, fn(a, b) { a - b }) {
            Some(value) => value
            None => VUnsupported("-")
          }
        "*" =>
          match number_binary(l, r, fn(a, b) { a * b }) {
            Some(value) => value
            None => VUnsupported("*")
          }
        "/" =>
          match number_binary(l, r, fn(a, b) { a / b }) {
            Some(value) => value
            None => VUnsupported("/")
          }
        "==" => VBool(l.to_text() == r.to_text())
        "!=" => VBool(l.to_text() != r.to_text())
        ">" => compare_values(l, r, ">")
        "<" => compare_values(l, r, "<")
        ">=" => compare_values(l, r, ">=")
        "<=" => compare_values(l, r, "<=")
        _ => VUnsupported(op)
      }
    }
  }
}

///|
fn compare_values(left : Value, right : Value, op : String) -> Value {
  match (left, right) {
    (VNumber(l), VNumber(r)) =>
      match (parse_number_value(l), parse_number_value(r)) {
        (Some(a), Some(b)) =>
          match op {
            ">" => VBool(a > b)
            "<" => VBool(a < b)
            ">=" => VBool(a >= b)
            "<=" => VBool(a <= b)
            _ => VUnsupported(op)
          }
        _ => compare_text(VNumber(l), VNumber(r), op)
      }
    _ => compare_text(left, right, op)
  }
}

///|
fn compare_text(left : Value, right : Value, op : String) -> Value {
  let l = left.to_text()
  let r = right.to_text()
  match op {
    ">" => VBool(l > r)
    "<" => VBool(l < r)
    ">=" => VBool(l >= r)
    "<=" => VBool(l <= r)
    _ => VUnsupported(op)
  }
}

///|
fn EvalContext::eval_builtin(
  self : EvalContext,
  name : String,
  args : Array[Argument],
) -> Value {
  match name {
    "Set" =>
      match args {
        [{ value: StateRef(target), .. }, { value, .. }] =>
          VAction([Set(target, self.eval(value))])
        _ => VAction([Unsupported("@Set expects a state reference and value")])
      }
    "Reset" =>
      match args {
        [{ value: StateRef(target), .. }] => VAction([Reset(target)])
        _ => VAction([Unsupported("@Reset expects a state reference")])
      }
    "Count" =>
      match args.get(0) {
        Some(arg) =>
          match self.eval(arg.value) {
            VArray(items) => VNumber(items.length().to_string())
            _ => VNumber("0")
          }
        None => VNumber("0")
      }
    _ => VUnsupported("@" + name)
  }
}

///|
fn merge_action_values(values : Array[Value]) -> Value {
  let steps : Array[ActionStep] = []
  for value in values {
    match value {
      VAction(action_steps) => steps.append(action_steps)
      VUnsupported(message) => steps.push(Unsupported(message))
      _ => ()
    }
  }
  VAction(steps)
}

///|
fn EvalContext::eval_call(
  self : EvalContext,
  name : String,
  args : Array[Argument],
) -> Value {
  if name == "Action" {
    let values : Array[Value] = []
    for arg in args {
      match self.eval(arg.value) {
        VArray(items) => values.append(items)
        other => values.push(other)
      }
    }
    return merge_action_values(values)
  }
  if name == "Query" || name == "Mutation" || name == "Run" {
    self.diagnostics.push(
      diagnostic(
        "unsupported-runtime",
        name + " is parsed but not executable in the Rabbita v0 runtime",
        target=name,
      ),
    )
    return VUnsupported(name)
  }
  let props : Map[String, Value] = {}
  let mut positional = 0
  match self.library.get(name) {
    Some(schema) => {
      let prop_names = schema.prop_names()
      for arg in args {
        match arg.name {
          Some(prop_name) => props[prop_name] = self.eval(arg.value)
          None =>
            match prop_names.get(positional) {
              Some(prop_name) => {
                props[prop_name] = self.eval(arg.value)
                positional += 1
              }
              None =>
                self.diagnostics.push(
                  diagnostic(
                    "excess-args",
                    "too many positional arguments",
                    target=name,
                  ),
                )
            }
        }
      }
      for required in schema.required_props() {
        match props.get(required) {
          Some(VNull) =>
            self.diagnostics.push(
              diagnostic(
                "null-required",
                "required prop is null",
                target=name + "." + required,
              ),
            )
          Some(_) => ()
          None =>
            self.diagnostics.push(
              diagnostic(
                "missing-required",
                "missing required prop",
                target=name + "." + required,
              ),
            )
        }
      }
    }
    None => {
      self.diagnostics.push(
        diagnostic("unknown-component", "unknown component", target=name),
      )
      for i, arg in args {
        let prop_name = arg.name.unwrap_or("_arg" + i.to_string())
        props[prop_name] = self.eval(arg.value)
      }
    }
  }
  VElement({ name, props })
}

///|
pub(all) struct RuntimeResult {
  root : Value
  state : RuntimeState
  diagnostics : Array[Diagnostic]
} derive(Debug)

///|
pub fn evaluate(
  parsed : ParseResult,
  library? : @schema.ComponentLibrary = @schema.default_library(),
  state? : RuntimeState,
) -> RuntimeResult {
  let diagnostics = parsed.diagnostics.copy()
  let runtime_state = state.unwrap_or(RuntimeState::new(parsed.program))
  let ctx = EvalContext::new(
    parsed.program,
    library,
    diagnostics,
    runtime_state,
  )
  let root = match parsed.program.entry {
    Some(entry) => ctx.eval_ref(entry)
    None => {
      diagnostics.push(diagnostic("empty-program", "no root statement"))
      VNull
    }
  }
  { root, state: runtime_state, diagnostics }
}
