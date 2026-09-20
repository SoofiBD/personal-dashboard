/**
 * Web/Rails adapter for the Paperling-derived editor.
 *
 * Paperling talks to Tauri (fs, dialogs) for load/save. In the dashboard all
 * persistence goes through the existing Rails endpoints, so this adapter maps
 * editor content onto the DOM hooks the server-rendered pages already use:
 * hidden textarea + save buttons + export forms.
 *
 * AI hook (added later by the user with a small model):
 * pass `aiConfig` to mount(); it is stored on the session and exposed via
 * `getAiConfig()`. The editor stays fully functional when it is absent.
 */

export interface AiConfig {
  endpoint: string;
  model: string;
  apiKey: string;
}

export interface MountOptions {
  /** Initial markdown content. */
  initialContent: string;
  /** Called with the current content whenever the user triggers save. */
  onSave: (content: string) => void;
  /** Optional live callback on every edit (wiring: keep hidden fields fresh). */
  onChange?: (content: string) => void;
  /** filename -> download URL map for `images/` preview rewriting. */
  assetMap?: Record<string, string>;
  /** Note titles for `[[wikilink]]` completion (notes surface). */
  wikilinkTargets?: string[];
  /** Future AI wiring. Passive until implemented. */
  aiConfig?: AiConfig | null;
  /** "split" | "editor" | "preview" initial mode for workspace mounts. */
  initialMode?: "split" | "editor" | "preview";
}

export interface EditorSession {
  getContent: () => string;
  setContent: (content: string) => void;
  /** Returns the AI config when the user wires one later; null until then. */
  getAiConfig: () => AiConfig | null;
  setAiConfig: (config: AiConfig | null) => void;
  destroy: () => void;
}

export function createSession(getContent: () => string, opts: { aiConfig?: AiConfig | null; onDestroy?: () => void }): EditorSession {
  let aiConfig: AiConfig | null = opts.aiConfig ?? null;
  return {
    getContent,
    setContent: () => undefined,
    getAiConfig: () => aiConfig,
    setAiConfig: (config) => {
      aiConfig = config;
    },
    destroy: () => opts.onDestroy?.(),
  };
}
