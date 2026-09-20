import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import { WorkspaceApp, type ViewMode } from "./editor/WorkspaceApp";
import { EditorPane } from "./editor/EditorPane";
import { PreviewPane } from "./preview/PreviewPane";
import { createSession, type AiConfig, type EditorSession, type MountOptions } from "./rails-adapter";
import "./styles.css";

function readJson<T>(value: string | null, fallback: T): T {
  if (!value) return fallback;
  try {
    return JSON.parse(value) as T;
  } catch {
    return fallback;
  }
}

function mountWorkspace(el: HTMLElement, opts: MountOptions): EditorSession {
  const source = el.querySelector<HTMLTextAreaElement>("[data-mde-source]");
  const initial = opts.initialContent || source?.value || "";
  const assetMap = opts.assetMap || readJson<Record<string, string>>(el.getAttribute("data-mde-assets"), {});
  const mode = (el.getAttribute("data-mde-mode") as ViewMode) || opts.initialMode || "split";

  let contentApi: { getContent: () => string; setContent: (c: string) => void } | null = null;

  // Export forms + save hooks live in the workspace section around the mount.
  const workspace = el.closest("[data-document-workspace]") ?? el;

  const mirror = (c: string) => {
    if (source) source.value = c;
    workspace.querySelectorAll<HTMLInputElement>("[data-mde-export]").forEach((input) => {
      input.value = c;
    });
    opts.onChange?.(c);
  };

  const root = createRoot(el.querySelector("[data-mde-app]") ?? el);
  root.render(
    <StrictMode>
      <WorkspaceApp
        initialContent={initial}
        assetMap={assetMap}
        aiConfig={opts.aiConfig ?? null}
        initialMode={mode}
        onContent={mirror}
        contentApiRef={(api) => {
          contentApi = api;
        }}
      />
    </StrictMode>
  );

  const getContent = () => contentApi?.getContent() ?? initial;
  const session = createSession(getContent, {
    aiConfig: opts.aiConfig ?? null,
    onDestroy: () => root.unmount(),
  });
  const full: EditorSession = {
    ...session,
    setContent: (c: string) => contentApi?.setContent(c),
  };
  (el as HTMLElement & { _mdSession?: EditorSession })._mdSession = full;

  // The bundle owns save/copy/gallery-insert on pages it mounts (the legacy
  // application.js workspace init skips [data-md-editor] roots).
  const feedback = workspace.querySelector("[data-workspace-feedback]");
  const say = (msg: string) => {
    if (feedback) feedback.textContent = msg;
  };
  const csrf = () => document.querySelector<HTMLMetaElement>("meta[name='csrf-token']")?.content || "";

  workspace.querySelectorAll("[data-copy-markdown]").forEach((btn) => {
    btn.addEventListener("click", async () => {
      try {
        await navigator.clipboard.writeText(getContent());
        say("Markdown panoya kopyalandı.");
      } catch {
        say("Kopyalama başarısız oldu.");
      }
    });
  });

  workspace.querySelectorAll("[data-save-markdown]").forEach((btn) => {
    btn.addEventListener("click", async () => {
      const url = (btn as HTMLElement).dataset.saveUrl;
      if (!url) return;
      const button = btn as HTMLButtonElement;
      const original = button.innerHTML;
      button.disabled = true;
      say("Markdown değişiklikleri kaydediliyor.");
      try {
        const response = await fetch(url, {
          method: "PATCH",
          headers: { "Content-Type": "application/json", Accept: "application/json", "X-CSRF-Token": csrf() },
          body: JSON.stringify({ document_conversion: { markdown_content: getContent() } }),
        });
        const result = await response.json().catch(() => ({}));
        if (!response.ok) throw new Error((result as { error?: string }).error || "Kaydetme başarısız oldu.");
        say("Markdown değişiklikleri kaydedildi.");
      } catch (error) {
        say(error instanceof Error ? error.message : "Kaydetme başarısız oldu; tekrar deneyin.");
      } finally {
        button.disabled = false;
        button.innerHTML = original;
      }
    });
  });

  // Gallery "Markdown'a ekle" buttons live outside the mount root.
  document.querySelectorAll("[data-insert-image]").forEach((btn) => {
    btn.addEventListener("click", () => {
      const b = btn as HTMLElement;
      const snippet = `![${b.dataset.imageAlt || ""}](images/${b.dataset.imageFilename || ""})`;
      const current = getContent();
      const prefix = current && !current.endsWith("\n") ? "\n\n" : "";
      full.setContent(`${current}${prefix}${snippet}\n\n`);
      say("Görsel Markdown'a eklendi. Değişikliği kalıcı yapmak için kaydedin.");
    });
  });

  return full;
}

function mountNotes(el: HTMLElement, opts: MountOptions): EditorSession {
  const source = el.querySelector<HTMLTextAreaElement>("textarea[data-notes-editor], [data-mde-source]");
  const initial = opts.initialContent || source?.value || "";
  if (source) source.style.display = "none";
  // Legacy wrap-button toolbar writes straight into the textarea; the bundle
  // owns the content once mounted, so hide it (it stays as a no-JS fallback).
  el.querySelectorAll(".notes-editor-toolbar").forEach((bar) => {
    (bar as HTMLElement).style.display = "none";
  });

  const app = document.createElement("div");
  app.setAttribute("data-mde-app", "");
  source?.after(app);

  let contentApi: { getContent: () => string; setContent: (c: string) => void } | null = null;
  const root = createRoot(app);

  const renderNotes = (preview: boolean, content: string) => {
    root.render(
      <StrictMode>
        <div className="mde-notes">
          <div className="mde-viewbar" role="group" aria-label="View">
            <button type="button" className={preview ? "" : "is-active"} onClick={() => renderNotes(false, contentApi?.getContent() ?? content)}>
              Editor
            </button>
            <button type="button" className={preview ? "is-active" : ""} onClick={() => renderNotes(true, contentApi?.getContent() ?? content)}>
              Preview
            </button>
          </div>
          {preview ? (
            <PreviewPane content={content} />
          ) : (
            <EditorPane
              initialContent={content}
              wikilinkTargets={opts.wikilinkTargets}
              onChange={(c) => {
                if (source) source.value = c;
                opts.onChange?.(c);
              }}
              onContentRef={(api) => {
                contentApi = api;
              }}
            />
          )}
        </div>
      </StrictMode>
    );
  };
  renderNotes(false, initial);

  // Ensure the hidden textarea always carries the latest content on submit.
  const form = el.closest("form") ?? source?.closest("form");
  form?.addEventListener("submit", () => {
    if (source && contentApi) source.value = contentApi.getContent();
  });

  const getContent = () => contentApi?.getContent() ?? source?.value ?? initial;
  const session = createSession(getContent, {
    aiConfig: opts.aiConfig ?? null,
    onDestroy: () => root.unmount(),
  });
  return { ...session, setContent: (c: string) => contentApi?.setContent(c) };
}

function autoMount() {
  document.querySelectorAll<HTMLElement>("[data-md-editor]").forEach((el) => {
    if ((el as HTMLElement & { _mdMounted?: boolean })._mdMounted) return;
    (el as HTMLElement & { _mdMounted?: boolean })._mdMounted = true;
    const kind = el.getAttribute("data-md-editor") || "workspace";
    const opts: MountOptions = {
      initialContent: el.getAttribute("data-mde-initial") ?? "",
      onSave: () => undefined,
      assetMap: readJson(el.getAttribute("data-mde-assets"), {}),
      wikilinkTargets: readJson<string[]>(el.getAttribute("data-mde-wikilinks"), []),
    };
    if (kind === "notes") mountNotes(el, opts);
    else mountWorkspace(el, opts);
  });
}

if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", autoMount);
} else {
  autoMount();
}

export { mountWorkspace, mountNotes, autoMount };
export type { AiConfig, EditorSession, MountOptions };
