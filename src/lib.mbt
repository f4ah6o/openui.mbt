///|
pub fn parse(
  input : String,
  schema? : @schema.ComponentLibrary = @schema.default_library(),
) -> @core.ParseResult {
  @core.parse(input, schema~)
}

///|
pub fn evaluate(
  parsed : @core.ParseResult,
  library? : @schema.ComponentLibrary = @schema.default_library(),
  state? : @core.RuntimeState,
) -> @core.RuntimeResult {
  match state {
    Some(state) => @core.evaluate(parsed, library~, state~)
    None => @core.evaluate(parsed, library~)
  }
}

///|
pub fn default_library() -> @schema.ComponentLibrary {
  @schema.default_library()
}
