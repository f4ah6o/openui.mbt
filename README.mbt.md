# openui.mbt

OpenUI Lang runtime for MoonBit with a Rabbita renderer.

This first version focuses on the OpenUI Lang v0.5 surface needed for static UI and local state: component statements, forward references, `$state` declarations, state references, and `@Set` / `@Reset` action steps. `Query`, `Mutation`, and tool execution are parsed as unsupported runtime features.

## Install

```bash
moon add f4ah6o/openui
```

## Parse And Evaluate

```mbt check
test {
  let parsed = @openui.parse(
    #|$name = "MoonBit"
    #|root = TextContent("Hello " + $name)
  )
  let result = @openui.evaluate(parsed)
  inspect(result.diagnostics, content="[]")
}
```

## Rabbita Rendering

```mbt nocheck
let parsed = @openui.parse(
  #|root = Stack([TextContent("Hello"), Button("OK")])
)
let html = @rabbita_renderer.render_to_html(parsed)
```

For deterministic tests and server-side snapshots, `f4ah6o/openui/rabbita` also exposes `render_static_string`.

## Supported Components

- `Stack`
- `Card`
- `TextContent`
- `Form`
- `FormControl`
- `Input`
- `Select`
- `Button`
- `Buttons`
- `Tabs`
- `Table`
- `BarChart`

## Development

```bash
just check
just test
just test-update
```
