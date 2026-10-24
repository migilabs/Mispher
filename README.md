# Mispher

Personal conversation recorder for Apple Watch, iPhone and Mac. Record a meeting, Teams call or voice note, and minutes later a German Protocol with Action items is in Apple Notes and queryable from Claude over MCP.

- Concept and mockups: [Mispher: Konzept mit Mockups](https://claude.ai/artifact/5D9rtWEP95cy7RVZDy5HMi)
- Status: P0, preparation. No app code yet.
- Rules for coding agents: [CLAUDE.md](CLAUDE.md)

## Working with Claude Code

This repo uses [Matt Pocock's skills](https://github.com/mattpocock/skills), vendored in `.claude/skills/` so they load in local and cloud sessions alike. Issues live in GitHub Issues.

- **Whole roadmap, open questions**: `/wayfinder` charts decision tickets on the issue tracker until the way is clear.
- **One phase or feature**: `/grill-with-docs` → `/to-spec` → `/to-tickets` → `/implement` (test-first with `/tdd`, closing with `/code-review`).
- **Not sure which**: `/ask-matt`.

Skill provenance, updates and license: [docs/agents/skills.md](docs/agents/skills.md).
