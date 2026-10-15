# Serving the library to an agent (MCP + CLI)

Generated markdown in a repository is only *present*. An agent is aware of a
component library when it can **ask a tool**: "what do you have for a loading
button", "show me the contract for Grid", "give me a call that compiles".

`tools/mcp/astryx-mcp.mjs` is that tool. It is a
[Model Context Protocol](https://modelcontextprotocol.io) server over stdio
(JSON-RPC 2.0), and it answers **only** from this repository's machine-readable
files:

| file | what it answers from |
| --- | --- |
| `registry.json` | upstream contract: props, defaults, keywords, descriptions |
| `port.json` | what actually exists in OCaml, and in which module |
| `snippets.json` | compile-verified OCaml calls (copied from `examples/demo/demo.ml`) |
| `docs/components/*.md` | the generated reference text |
| `tokens.ocaml.json` | token names and values |

Because every answer is read from those files, the server cannot describe a
component, prop or snippet that does not exist — and for an **unported**
component it refuses to invent a call, returning the upstream prop list to
design against instead.

## Tools

| tool | arguments | returns |
| --- | --- | --- |
| `list_components` | `filter` (`all`/`ported`), `limit` | every component with its status and module |
| `search_components` | `query`, `limit` | intent search over name, description, keywords and prop names |
| `get_component` | `name` | status, upstream props, compile-verified call, full reference text |
| `get_snippet` | `name` | a compiling OCaml call, or an explicit refusal if unported |
| `get_tokens` | `group` (optional) | token groups and values, by name |
| `get_status` | — | how many components are ported, by milestone, with modules |

## Use it from a shell

```sh
node tools/mcp/astryx-mcp.mjs --cli status
node tools/mcp/astryx-mcp.mjs --cli search "loading button"
node tools/mcp/astryx-mcp.mjs --cli snippet Grid
node tools/mcp/astryx-mcp.mjs --cli get Grid
node tools/mcp/astryx-mcp.mjs --cli tokens color
```

## Wire it into an MCP client

Standard stdio server configuration:

```json
{
  "mcpServers": {
    "astryx": {
      "command": "node",
      "args": ["/absolute/path/to/bonsai-astryx/tools/mcp/astryx-mcp.mjs"]
    }
  }
}
```

For Hermes Agent specifically, see its documentation at
<https://hermes-agent.nousresearch.com/docs> for where that block goes in
`config.yaml` — the server side needs no Hermes-specific behaviour.

## How it was tested

Protocol behaviour was exercised by piping raw JSON-RPC frames in and checking
every reply, including the negative paths:

- `initialize` → protocol version and `capabilities.tools`
- `notifications/initialized` → **no reply** (a notification must not be answered)
- `tools/list` → the six tools above
- `tools/call` → real content for `get_snippet`, `list_components`
- `tools/call` with an unknown tool → `isError: true`, not a crash
- an unknown method → JSON-RPC error `-32601`

To re-run it yourself:

```sh
printf '%s\n' \
 '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}' \
 '{"jsonrpc":"2.0","id":2,"method":"tools/list"}' \
 | node tools/mcp/astryx-mcp.mjs
```
