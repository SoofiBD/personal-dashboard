# md-editor

Paperling-derived Markdown editor + live preview for the Rails dashboard.
Web-only: no Tauri. Persistence goes through existing Rails endpoints.

## Layout

- `src/editor/` — CodeMirror 6 pane, workspace shell (split/editor/preview + scroll sync)
- `src/preview/` — react-markdown preview (GFM, math/KaTeX, mermaid, sanitize)
- `src/utils/` — pure helpers copied from Paperling (see NOTICE.md)
- `src/rails-adapter.ts` — mount options + session
- `src/mount.tsx` — `window.MdEditor` entry, auto-mounts `[data-md-editor]`

## Build

Requires node on the host (Docker image has none):

```sh
./build.sh   # npm ci + build -> ../../vendor/assets/javascripts/md-editor/
```

Commit the bundle output. `config/initializers/assets.rb` precompiles it.

## Mount contract

- Workspace (`data-md-editor="workspace"`): hidden `[data-mde-source]` textarea +
  `[data-mde-app]` root + `[data-mde-assets]` JSON. Bundle mirrors content into
  `[data-mde-export]` hidden fields and owns `[data-save-markdown]`,
  `[data-copy-markdown]`, `[data-insert-image]` on the page.
- Notes (`data-md-editor="notes"`): wraps the form, hides the textarea, syncs live.

## AI hook (planned)

`MountOptions.aiConfig = { endpoint, model, apiKey }` is accepted, stored on the
session (`getAiConfig`/`setAiConfig`) and currently passive. Future work: wire it
to `AIBubble`-style inline accept/reject against the dashboard `ai_settings`.
