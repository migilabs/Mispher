# Vendored skills

`.claude/skills/` holds Matt Pocock's promoted skills (the `engineering` and `productivity` buckets, the same 27 his Claude Code plugin ships), copied as plain files.

- **Source**: https://github.com/mattpocock/skills
- **Pinned commit**: `5beb35b040e3de97e54fa9e386d7e42d15c295c2` (2026-10-19, plugin version 1.3.1)

## Why vendored instead of the plugin

Claude Code cloud sessions load skills committed under `.claude/skills/`, but don't install plugins a repo enables in `.claude/settings.json`. Vendoring makes the skills available locally and in the cloud alike. Keep the plugin (`mattpocock-skills@claude-plugins-official`) uninstalled on machines that work in this repo, or every skill appears twice.

## Updating

```bash
Scripts/sync-mattpocock-skills.sh          # latest main
Scripts/sync-mattpocock-skills.sh <sha>    # a specific commit
```

Then set the pinned commit above, review `git diff .claude/skills`, and commit. The script overwrites each vendored skill folder, so record any local edit to a skill in **Local changes** below and re-apply it after a sync. Skills deleted upstream stay until you remove them.

## Local changes

None.

## Name collision

`code-review` replaces Claude Code's built-in `/code-review` in this repo; that's the one `/implement` and `/implement-spec` close out with. The built-in review stays reachable as `/review`.

## License

```
MIT License

Copyright (c) 2026 Matt Pocock

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```
