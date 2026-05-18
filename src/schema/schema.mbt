///|
pub(all) enum ValueKind {
  Any
  String
  Number
  Bool
  Array
  Object
  Node
  Action
} derive(Debug, Eq)

///|
pub(all) struct PropSpec {
  name : String
  required : Bool
  kind : ValueKind
} derive(Debug, Eq)

///|
pub(all) struct ComponentSchema {
  name : String
  props : Array[PropSpec]
} derive(Debug, Eq)

///|
pub(all) struct ComponentLibrary {
  components : Map[String, ComponentSchema]
} derive(Debug)

///|
pub fn prop(
  name : String,
  required? : Bool = false,
  kind? : ValueKind = Any,
) -> PropSpec {
  { name, required, kind }
}

///|
pub fn component(name : String, props : Array[PropSpec]) -> ComponentSchema {
  { name, props }
}

///|
pub fn ComponentSchema::prop_names(self : ComponentSchema) -> Array[String] {
  self.props.map(p => p.name)
}

///|
pub fn ComponentSchema::required_props(self : ComponentSchema) -> Array[String] {
  self.props.filter_map(p => if p.required { Some(p.name) } else { None })
}

///|
pub fn ComponentLibrary::get(
  self : ComponentLibrary,
  name : String,
) -> ComponentSchema? {
  self.components.get(name)
}

///|
pub fn library(components : Array[ComponentSchema]) -> ComponentLibrary {
  let map : Map[String, ComponentSchema] = {}
  for component in components {
    map[component.name] = component
  }
  { components: map }
}

///|
pub fn default_library() -> ComponentLibrary {
  library([
    component("Stack", [
      prop("children", required=true, kind=Array),
      prop("direction", kind=String),
      prop("gap", kind=String),
    ]),
    component("Card", [
      prop("children", required=true, kind=Array),
      prop("title", kind=String),
    ]),
    component("TextContent", [
      prop("content", required=true, kind=String),
      prop("variant", kind=String),
    ]),
    component("Form", [
      prop("children", required=true, kind=Array),
      prop("onSubmit", kind=Action),
    ]),
    component("FormControl", [
      prop("label", required=true, kind=String),
      prop("control", required=true, kind=Node),
    ]),
    component("Input", [
      prop("value", kind=Any),
      prop("placeholder", kind=String),
      prop("type", kind=String),
      prop("onChange", kind=Action),
    ]),
    component("Select", [
      prop("value", kind=Any),
      prop("options", required=true, kind=Array),
      prop("onChange", kind=Action),
    ]),
    component("Button", [
      prop("label", required=true, kind=String),
      prop("onClick", kind=Action),
      prop("variant", kind=String),
    ]),
    component("Buttons", [prop("buttons", required=true, kind=Array)]),
    component("Tabs", [
      prop("tabs", required=true, kind=Array),
      prop("value", kind=Any),
      prop("onChange", kind=Action),
    ]),
    component("Table", [
      prop("columns", required=true, kind=Array),
      prop("rows", required=true, kind=Array),
    ]),
    component("BarChart", [
      prop("data", required=true, kind=Array),
      prop("x", kind=String),
      prop("y", kind=String),
    ]),
  ])
}
