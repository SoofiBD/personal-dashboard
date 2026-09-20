import { useCallback, useRef, useState } from "react";
import { EditorPane } from "../editor/EditorPane";
import { PreviewPane } from "../preview/PreviewPane";
import { createScrollSync } from "../utils/scrollSync";
import type { AiConfig } from "../rails-adapter";

export type ViewMode = "split" | "editor" | "preview";

export interface WorkspaceAppProps {
  initialContent: string;
  assetMap?: Record<string, string>;
  aiConfig?: AiConfig | null;
  initialMode?: ViewMode;
  onContent?: (content: string) => void;
  contentApiRef?: (api: { getContent: () => string; setContent: (c: string) => void }) => void;
}

export function WorkspaceApp({ initialContent, assetMap, aiConfig, initialMode, onContent, contentApiRef }: WorkspaceAppProps) {
  void aiConfig; // passive until the user wires a small model later
  const [content, setContent] = useState(initialContent);
  const [mode, setMode] = useState<ViewMode>(initialMode ?? "split");
  const syncRef = useRef(createScrollSync());
  const onContentRef = useRef(onContent);
  onContentRef.current = onContent;

  const handleContent = useCallback((c: string) => {
    setContent(c);
    onContentRef.current?.(c);
  }, []);

  const applyMode = useCallback((m: ViewMode) => {
    setMode(m);
    syncRef.current.setEnabled(m === "split");
  }, []);

  return (
    <div className={`mde-workspace mde-mode-${mode}`}>
      <div className="mde-viewbar" role="group" aria-label="View">
        {(["split", "editor", "preview"] as ViewMode[]).map((m) => (
          <button key={m} type="button" className={m === mode ? "is-active" : ""} onClick={() => applyMode(m)}>
            {m === "split" ? "Split" : m === "editor" ? "Editor" : "Preview"}
          </button>
        ))}
      </div>
      <div className="mde-grid">
        {(mode === "split" || mode === "editor") && (
          <EditorPane
            initialContent={initialContent}
            onChange={handleContent}
            onScrollFraction={(f) => syncRef.current.notify("code", f)}
            registerScroller={(s) => syncRef.current.register("code", s)}
            onContentRef={contentApiRef}
          />
        )}
        {(mode === "split" || mode === "preview") && (
          <PreviewPane
            content={content}
            assetMap={assetMap}
            onScrollFraction={(f) => syncRef.current.notify("preview", f)}
            registerScroller={(s) => syncRef.current.register("preview", s)}
          />
        )}
      </div>
    </div>
  );
}
