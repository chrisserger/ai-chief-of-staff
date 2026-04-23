# Additional MCP Servers — Image Generation, Diagramming, Search

These are optional MCP (Model Context Protocol) servers that extend Claude's capabilities. Add them when you're ready for more.

## Nano Banana — Image Generation

Generate images using Google's Gemini models. Claude can create diagrams, charts, visuals, and save them directly to your Obsidian vault.

### Install

```bash
claude mcp add nanobanana --transport stdio -- uvx nanobanana
```

### What it does

- **Generate images** from text descriptions (Gemini 3.1 Flash for speed, Gemini 3 Pro for quality)
- **Edit existing images** — modify, enhance, restyle
- **4K resolution** output
- **Google Search grounding** — can reference real-world visual styles
- **Subject consistency** — maintain visual coherence across multiple images

### Use cases

- Architecture diagrams for presentations
- Visual org charts
- Process flow diagrams
- Competitive landscape visuals
- Any image you'd normally create in a design tool

### How to use

Just ask Claude: "Create a diagram showing our team structure" or "Generate an image of [description]." Claude creates the image and can save it to your vault.

### Requirements

- Python with `uvx` available (`pip install uvx` or `pipx install uvx`)
- `GEMINI_API_KEY` environment variable (get from [aistudio.google.com](https://aistudio.google.com/))

---

## Draw.io — Programmatic Diagramming

Create and edit draw.io diagrams via MCP. Full CRUD — create diagrams, add shapes, connect nodes, export.

### Install

Two servers work together — add both:

```bash
# Remote server (main functionality)
claude mcp add drawio --transport http https://mcp.draw.io/mcp

# Local tools (file operations)
claude mcp add drawio-tools --transport stdio -- npx @drawio/mcp
```

### What it does

- Create draw.io diagrams from scratch
- Add and connect shapes programmatically
- Edit existing diagrams
- Export to various formats
- Save `.drawio` files to your vault (viewable in Obsidian with the draw.io plugin)

### Use cases

- Org charts
- Architecture diagrams
- Process flows
- Network diagrams
- Anything you'd draw in draw.io/diagrams.net

---

## Pinecone — Semantic Vector Search

Search your entire knowledge base by meaning, not just keywords. "What do I know about competitive pricing concerns" returns semantically relevant results from daily notes, deal briefs, customer files, etc.

### Install

Pinecone is available as a Claude Code plugin:

```bash
claude mcp add pinecone
```

Or add via Claude Code settings if it's available as a built-in plugin.

### Setup

1. **Get a Pinecone API key** from [pinecone.io](https://www.pinecone.io/) (free tier works)
2. **Set the environment variable:**
   ```bash
   echo 'export PINECONE_API_KEY=your-key-here' >> ~/.zshrc
   source ~/.zshrc
   ```
3. **Create an index** — ask Claude: "Set up Pinecone for my knowledge base." Claude will create an index with the right configuration.
4. **Index your files** — Claude will create an indexing script that chunks your markdown files and upserts them to Pinecone.

### Index config

| Setting | Value |
|---------|-------|
| **Embeddings** | `multilingual-e5-large` (server-side) |
| **Metric** | Cosine |
| **Dimensions** | 1024 |
| **Content** | All markdown files chunked by `##` headers |
| **Fields** | `content`, `source_file`, `section`, `file_type`, `date` |

### Use cases

- "What do I know about [customer]?" — finds relevant mentions across all files
- "Find discussions about pricing concerns" — semantic, not keyword
- "What patterns do I see in lost deals?" — searches deal briefs and analysis
- Meeting prep — Claude searches for all context about attendees and topics

---

## Verifying MCP Servers

After adding any MCP server, restart Claude Code and verify:

```bash
claude mcp list
```

You should see all configured servers. If a server doesn't appear, check:
- The command is correct (typos in the `claude mcp add` command)
- Required dependencies are installed (`uvx`, `npx`, etc.)
- API keys are set in your environment
