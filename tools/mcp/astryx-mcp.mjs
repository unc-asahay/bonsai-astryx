#!/usr/bin/env node
// astryx-mcp — serve this library's reference corpus to an AI agent.
//
// Why this exists: generated markdown sitting in a repository is only *present*.
// An agent is aware of a component library when it can ask a tool "what do you
// have for X", "show me the contract for Y", "give me a call that compiles".
// This is that tool: a Model Context Protocol server (stdio, JSON-RPC 2.0) over
// registry.json (upstream contract), port.json (what is ported), snippets.json
// (compile-verified calls) and docs/components/*.md (the reference text).
//
// Every answer is read from those machine-readable files, so the assistant can
// never be told about a component, prop or snippet that does not exist.
//
// Two modes:
//   node tools/mcp/astryx-mcp.mjs                # MCP server on stdio
//   node tools/mcp/astryx-mcp.mjs --cli <cmd>     # same tools from a shell
//
// CLI commands: list [all|ported] | search <query> | get <Name> | snippet <Name>
//               | tokens [group] | status

import { readFileSync, existsSync } from "node:fs";
import { resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "../..");

const readJson = (p) => JSON.parse(readFileSync(resolve(root, p), "utf8"));

const registry = readJson("registry.json");
const port = readJson("port.json");
const tokens = readJson("tokens.ocaml.json");
const snippets = existsSync(resolve(root, "snippets.json"))
  ? readJson("snippets.json").snippets
  : {};

const upstreamComponents = (() => {
  const entries = Array.isArray(registry) ? registry : registry.components ?? registry.items;
  return entries.map((e) => ({
    name: e.name ?? e.component,
    props: e.props ?? [],
    description: e.description ?? "",
    keywords: e.keywords ?? [],
    a11y: e.accessibility ?? e.a11y ?? null,
    anatomy: e.anatomy ?? null,
    rules: e.rules ?? null,
  }));
})();

const portedByName = new Map(port.ported.map((p) => [p.component, p]));

const componentView = (c) => ({
  name: c.name,
  status: portedByName.has(c.name) ? "ported" : "not_ported",
  module: portedByName.get(c.name)?.module ?? null,
  milestone: portedByName.get(c.name)?.milestone ?? null,
  source: portedByName.get(c.name)?.file ?? null,
  has_snippet: Boolean(snippets[c.name]),
  props_count: Array.isArray(c.props) ? c.props.length : 0,
  summary: (c.description || "").split("\n")[0].slice(0, 160),
});

function readReference(name) {
  const p = resolve(root, "docs/components", `${name}.md`);
  return existsSync(p) ? readFileSync(p, "utf8") : null;
}

function findComponent(name) {
  if (!name) return null;
  const lower = String(name).toLowerCase();
  return (
    upstreamComponents.find((c) => c.name.toLowerCase() === lower) ??
    upstreamComponents.find((c) => c.name.toLowerCase().replace(/[^a-z]/g, "") === lower.replace(/[^a-z]/g, "")) ??
    null
  );
}

// ---------------------------------------------------------------- the tools

const tools = {
  list_components({ filter = "all", limit = 200 } = {}) {
    const rows = upstreamComponents
      .map(componentView)
      .filter((c) => (filter === "ported" ? c.status === "ported" : true))
      .slice(0, limit);
    const ported = upstreamComponents.filter((c) => portedByName.has(c.name)).length;
    return [
      `${rows.length} component(s)${filter === "ported" ? " ported" : ""} — ${ported} of ${upstreamComponents.length} ported overall.`,
      "",
      ...rows.map(
        (c) =>
          `- ${c.name} [${c.status}]${c.module ? ` ${c.module}` : ""}${
            c.props_count ? ` · ${c.props_count} upstream props` : ""
          }`,
      ),
    ].join("\n");
  },

  search_components({ query, limit = 15 } = {}) {
    if (!query) return "search_components needs a `query` (e.g. 'loading button', 'grid columns').";
    const terms = String(query).toLowerCase().split(/\s+/).filter(Boolean);
    const scored = upstreamComponents.map((c) => {
      const haystack = [
        c.name,
        c.description,
        ...(c.keywords ?? []),
        ...(c.props ?? []).map((p) => (typeof p === "string" ? p : p.name ?? "")),
      ]
        .join(" ")
        .toLowerCase();
      let score = 0;
      for (const t of terms) {
        if (c.name.toLowerCase() === t) score += 10;
        if (c.name.toLowerCase().includes(t)) score += 6;
        const hits = haystack.split(t).length - 1;
        score += Math.min(hits, 4);
      }
      if (portedByName.has(c.name)) score += 2; // a ported component is more actionable
      return { c, score };
    });
    const hits = scored.filter((s) => s.score > 0).sort((a, b) => b.score - a.score).slice(0, limit);
    if (hits.length === 0) return `No component matches "${query}".`;
    return [
      `matches for "${query}":`,
      "",
      ...hits.map(({ c }) => {
        const v = componentView(c);
        return `- ${v.name} [${v.status}] — ${v.summary || "(no summary)"}`;
      }),
      "",
      "Use get_component for a full contract, snippet for a compiling call.",
    ].join("\n");
  },

  get_component({ name } = {}) {
    const c = findComponent(name);
    if (!c) {
      const names = upstreamComponents.map((x) => x.name);
      const near = names.filter((n) => n.toLowerCase().includes(String(name ?? "").toLowerCase().slice(0, 3)));
      return `No component named "${name}".${near.length ? ` Did you mean: ${near.slice(0, 8).join(", ")}?` : ""}`;
    }
    const v = componentView(c);
    const header = [
      `# ${v.name}`,
      `status: ${v.status}${v.module ? ` — module ${v.module} (${v.source}, milestone ${v.milestone})` : ""}`,
      v.summary ? `summary: ${v.summary}` : "",
    ]
      .filter(Boolean)
      .join("\n");
    const doc = readReference(c.name);
    const props = (c.props ?? [])
      .map((p) => (typeof p === "string" ? `- ${p}` : `- ${p.name}${p.type ? `: ${p.type}` : ""}${p.default != null ? ` (default ${p.default})` : ""}`))
      .join("\n");
    return [
      header,
      "",
      props ? `## upstream props\n\n${props}` : "",
      "",
      snippets[c.name] ? `## compile-verified call\n\n\`\`\`ocaml\n${snippets[c.name]}\n\`\`\`` : "",
      "",
      doc ? `## reference text\n\n${doc}` : "(no generated reference text for this component)",
    ]
      .filter(Boolean)
      .join("\n");
  },

  get_snippet({ name } = {}) {
    const c = findComponent(name);
    if (!c) return `No component named "${name}".`;
    const v = componentView(c);
    // port.json stores the module under its public path ("Astryx.Field_status"), so do not
    // prefix again — the component name and the module name can also differ.
    const mod = (v.module ?? c.name).replace(/^Astryx\./, "");
    if (snippets[c.name]) {
      return `Astryx.${mod} — ported${v.milestone ? ` (milestone ${v.milestone})` : ""}\n\n\`\`\`ocaml\n${snippets[c.name]}\n\`\`\`\n\nThis exact call shape is compiled by dune build in examples/demo/demo.ml or examples/showcase/showcase.ml.`;
    }
    const contract = (c.props ?? [])
      .map((p) => (typeof p === "string" ? p : p.name))
      .slice(0, 12)
      .join(", ");
    if (v.status === "ported") {
      // Ported but unsnippeted is NOT the same as unported: say which one it is, name the
      // real module (it can differ from the component name — DropdownMenu is
      // Astryx.Dropdown_menu), and never invent a call.
      return `${c.name} IS ported — but this build ships no compile-verified snippet for it, so I will not invent a call. Module: Astryx.${mod} (milestone ${v.milestone}). The call shape that is actually compiled is in examples/showcase/showcase.ml; the upstream props it answers to: ${contract}. See docs/components/${c.name}.md and docs/visual/${c.name}.md.`;
    }
    return `${c.name} is NOT ported yet, so there is no call to give you — anything I emit would be invented. Upstream props to design against: ${contract}. See docs/components/${c.name}.md.`;
  },

  get_tokens({ group } = {}) {
    const groups = Object.keys(tokens);
    if (!group) {
      return [
        `token groups: ${groups.join(", ")}`,
        "",
        ...groups.map((g) => {
          const v = tokens[g];
          const n = v && typeof v === "object" ? Object.keys(v).length : 0;
          const sample = v && typeof v === "object" ? Object.keys(v).slice(0, 6).join(", ") : "";
          return `- ${g} (${n}): ${sample}`;
        }),
        "",
        "Values live in assets/tokens.css — use them by name, never as literal colours.",
      ].join("\n");
    }
    const v = tokens[group];
    if (!v) return `No token group "${group}". Groups: ${groups.join(", ")}`;
    const entries = Object.entries(v);
    return [`${group} (${entries.length} tokens)`, "", ...entries.map(([k, val]) => `- ${k} = ${JSON.stringify(val)}`)].join("\n");
  },

  get_status() {
    const ported = port.ported;
    const byMilestone = ported.reduce((acc, p) => {
      acc[p.milestone] = (acc[p.milestone] ?? 0) + 1;
      return acc;
    }, {});
    return [
      `upstream: ${port.upstream.repo} @ ${port.upstream.commit} (${port.upstream.license})`,
      `ported: ${ported.length} of ${upstreamComponents.length}`,
      `by milestone: ${Object.entries(byMilestone).map(([m, n]) => `${m}=${n}`).join(", ")}`,
      `milestones: ${port.milestones.map((m) => `${m.id} (${m.status})`).join(", ")}`,
      "",
      `ported modules: ${ported.map((p) => p.module).join(", ")}`,
    ].join("\n");
  },
};

const toolDefs = [
  {
    name: "list_components",
    description: "List the component library. filter=\"ported\" for only what exists in OCaml.",
    inputSchema: {
      type: "object",
      properties: {
        filter: { type: "string", enum: ["all", "ported"] },
        limit: { type: "number" },
      },
    },
  },
  {
    name: "search_components",
    description: "Find components by intent, name, prop or keyword (e.g. 'loading button', 'grid columns').",
    inputSchema: {
      type: "object",
      properties: { query: { type: "string" }, limit: { type: "number" } },
      required: ["query"],
    },
  },
  {
    name: "get_component",
    description: "Full contract for one component: status, upstream props, compile-verified OCaml call, reference text.",
    inputSchema: { type: "object", properties: { name: { type: "string" } }, required: ["name"] },
  },
  {
    name: "get_snippet",
    description: "A compile-verified OCaml call for a ported component; refuses to invent one for unported components.",
    inputSchema: { type: "object", properties: { name: { type: "string" } }, required: ["name"] },
  },
  {
    name: "get_tokens",
    description: "Design token names and values; call with no group to list groups.",
    inputSchema: { type: "object", properties: { group: { type: "string" } } },
  },
  {
    name: "get_status",
    description: "Port status: how many components exist in OCaml, by milestone, with modules.",
    inputSchema: { type: "object", properties: {} },
  },
];

// ---------------------------------------------------------------- CLI mode

const argv = process.argv.slice(2);
if (argv[0] === "--cli" || argv[0] === "-c") {
  const [cmd, ...rest] = argv.slice(1);
  const arg = rest.join(" ");
  const out =
    cmd === "list"
      ? tools.list_components({ filter: arg === "ported" ? "ported" : "all" })
      : cmd === "search"
        ? tools.search_components({ query: arg })
        : cmd === "get"
          ? tools.get_component({ name: arg })
          : cmd === "snippet"
            ? tools.get_snippet({ name: arg })
            : cmd === "tokens"
              ? tools.get_tokens({ group: arg || undefined })
              : cmd === "status"
                ? tools.get_status()
                : `commands: list [all|ported] | search <query> | get <Name> | snippet <Name> | tokens [group] | status`;
  console.log(out);
  process.exit(0);
}

// ---------------------------------------------------------------- MCP server

function send(message) {
  process.stdout.write(JSON.stringify(message) + "\n");
}

function handle(msg) {
  const { id, method, params } = msg;
  switch (method) {
    case "initialize":
      return {
        jsonrpc: "2.0",
        id,
        result: {
          protocolVersion: params?.protocolVersion ?? "2024-11-05",
          capabilities: { tools: {} },
          serverInfo: { name: "astryx-mcp", version: "0.1.0" },
        },
      };
    case "notifications/initialized":
      return null; // notification: no reply
    case "tools/list":
      return { jsonrpc: "2.0", id, result: { tools: toolDefs } };
    case "tools/call": {
      const name = params?.name;
      const args = params?.arguments ?? {};
      const fn = tools[name];
      if (!fn) {
        return {
          jsonrpc: "2.0",
          id,
          result: { content: [{ type: "text", text: `unknown tool "${name}"` }], isError: true },
        };
      }
      try {
        return { jsonrpc: "2.0", id, result: { content: [{ type: "text", text: fn(args) }] } };
      } catch (err) {
        return {
          jsonrpc: "2.0",
          id,
          result: { content: [{ type: "text", text: `tool "${name}" failed: ${err.message}` }], isError: true },
        };
      }
    }
    default:
      return {
        jsonrpc: "2.0",
        id,
        error: { code: -32601, message: `method not found: ${method}` },
      };
  }
}

let buffer = "";
process.stdin.setEncoding("utf8");
process.stdin.on("data", (chunk) => {
  buffer += chunk;
  let idx;
  while ((idx = buffer.indexOf("\n")) >= 0) {
    const line = buffer.slice(0, idx).trim();
    buffer = buffer.slice(idx + 1);
    if (!line) continue;
    let msg;
    try {
      msg = JSON.parse(line);
    } catch {
      continue; // ignore unparseable frames rather than dying mid-session
    }
    const reply = handle(msg);
    if (reply && reply.id !== undefined) send(reply);
  }
});
