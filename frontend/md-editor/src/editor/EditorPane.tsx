import { useEffect, useRef, useCallback, useState } from "react";
import { EditorState as CMState, Compartment } from "@codemirror/state";
import {
  EditorView,
  keymap,
  lineNumbers,
  highlightActiveLine,
  drawSelection,
  dropCursor,
  type ViewUpdate,
} from "@codemirror/view";
import { history, defaultKeymap, historyKeymap } from "@codemirror/commands";
import { markdown } from "@codemirror/lang-markdown";
import { syntaxHighlighting, HighlightStyle } from "@codemirror/language";
import { searchKeymap } from "@codemirror/search";
import { tags as t } from "@lezer/highlight";
import {
  handleTab,
  handleEnter,
  wrapSelection,
  insertLink,
  type EditorState as TextState,
} from "../utils/editorActions";
import {
  pasteUrlOnSelection,
  pasteUrlAutolink,
  pasteTsvAsTable,
  htmlToMarkdown,
} from "../utils/smartPaste";
import { createScrollSync, type Scroller } from "../utils/scrollSync";

const highlightStyle = HighlightStyle.define([
  { tag: t.heading1, fontWeight: "700", fontSize: "1.25em" },
  { tag: t.heading2, fontWeight: "700", fontSize: "1.15em" },
  { tag: t.heading3, fontWeight: "700" },
  { tag: t.strong, fontWeight: "700" },
  { tag: t.emphasis, fontStyle: "italic" },
  { tag: t.monospace, fontFamily: "monospace" },
  { tag: t.link, textDecoration: "underline" },
  { tag: t.quote, fontStyle: "italic" },
]);

export interface EditorPaneProps {
  initialContent: string;
  onChange: (content: string) => void;
  onScrollFraction?: (fraction: number) => void;
  registerScroller?: (scroller: Scroller | null) => void;
  onContentRef?: (api: { getContent: () => string; setContent: (c: string) => void }) => void;
  wikilinkTargets?: string[];
}

function toTextState(view: EditorView): TextState {
  const sel = view.state.selection.main;
  return { text: view.state.doc.toString(), selStart: sel.from, selEnd: sel.to };
}

function applyResult(view: EditorView, result: { text: string; selStart: number; selEnd: number } | null): boolean {
  if (!result) return false;
  view.dispatch({
    changes: { from: 0, to: view.state.doc.length, insert: result.text },
    selection: { anchor: result.selStart, head: result.selEnd },
  });
  return true;
}

export function EditorPane({ initialContent, onChange, onScrollFraction, registerScroller, onContentRef, wikilinkTargets }: EditorPaneProps) {
  const hostRef = useRef<HTMLDivElement | null>(null);
  const viewRef = useRef<EditorView | null>(null);
  const onChangeRef = useRef(onChange);
  onChangeRef.current = onChange;
  const [findOpen, setFindOpen] = useState(false);

  const runWrap = useCallback((prefix: string, suffix = "") => {
    const view = viewRef.current;
    if (!view) return;
    applyResult(view, wrapSelection(toTextState(view), prefix, suffix));
    view.focus();
  }, []);

  useEffect(() => {
    const host = hostRef.current;
    if (!host) return;

    const sync = createScrollSync();
    const codeScroller: Scroller = {
      setFraction: (f: number) => {
        const view = viewRef.current;
        if (!view) return;
        const scroller = view.scrollDOM;
        scroller.scrollTop = f * (scroller.scrollHeight - scroller.clientHeight);
      },
    };
    sync.register("code", codeScroller);
    registerScroller?.(codeScroller);

    const state = CMState.create({
      doc: initialContent,
      extensions: [
        lineNumbers(),
        highlightActiveLine(),
        drawSelection(),
        dropCursor(),
        history(),
        markdown(),
        syntaxHighlighting(highlightStyle),
        keymap.of([
          ...defaultKeymap,
          ...historyKeymap,
          ...searchKeymap,
          {
            key: "Tab",
            run: (view) => applyResult(view, handleTab(toTextState(view), false)),
            shift: (view) => applyResult(view, handleTab(toTextState(view), true)),
          },
          {
            key: "Enter",
            run: (view) => applyResult(view, handleEnter(toTextState(view))),
          },
        ]),
        EditorView.lineWrapping,
        EditorView.updateListener.of((update: ViewUpdate) => {
          if (update.docChanged) onChangeRef.current(update.state.doc.toString());
        }),
        EditorView.domEventHandlers({
          paste: (event, view) => {
            const text = event.clipboardData?.getData("text/plain") ?? "";
            const html = event.clipboardData?.getData("text/html") ?? "";
            if (!text && !html) return false;
            const st = toTextState(view);
            if (text && (applyResult(view, pasteUrlOnSelection(st, text)) || applyResult(view, pasteTsvAsTable(st, text)))) {
              event.preventDefault();
              return true;
            }
            if (html) {
              event.preventDefault();
              void htmlToMarkdown(html).then((md) => {
                const cur = toTextState(view);
                applyResult(view, pasteTsvAsTable(cur, md) ?? pasteUrlAutolink(cur, md));
              });
              return true;
            }
            if (text) return applyResult(view, pasteUrlAutolink(st, text));
            return false;
          },
        }),
      ],
    });

    const view = new EditorView({ state, parent: host });
    viewRef.current = view;

    const scroller = view.scrollDOM;
    const onScroll = () => {
      const max = scroller.scrollHeight - scroller.clientHeight;
      const fraction = max > 0 ? scroller.scrollTop / max : 0;
      sync.notify("code", fraction);
      onScrollFraction?.(fraction);
    };
    scroller.addEventListener("scroll", onScroll, { passive: true });

    onContentRef?.({
      getContent: () => view.state.doc.toString(),
      setContent: (c: string) => {
        view.dispatch({ changes: { from: 0, to: view.state.doc.length, insert: c } });
        onChangeRef.current(c);
      },
    });

    return () => {
      scroller.removeEventListener("scroll", onScroll);
      registerScroller?.(null);
      view.destroy();
      viewRef.current = null;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  return (
    <div className="mde-root">
      <div className="mde-toolbar" role="toolbar" aria-label="Markdown">
        <button type="button" title="Bold" onClick={() => runWrap("**", "**")}><strong>B</strong></button>
        <button type="button" title="Italic" onClick={() => runWrap("*", "*")}><em>I</em></button>
        <button type="button" title="Heading" onClick={() => runWrap("## ")}>H</button>
        <button type="button" title="Link" onClick={() => {
          const view = viewRef.current;
          if (!view) return;
          applyResult(view, insertLink(toTextState(view)));
          view.focus();
        }}>Link</button>
        <button type="button" title="Bullet list" onClick={() => runWrap("- ")}>&bull; List</button>
        <button type="button" title="Task" onClick={() => runWrap("- [ ] ")}>Task</button>
        <button type="button" title="Code" onClick={() => runWrap("`", "`")}>Code</button>
        <button type="button" title="Find & replace (Ctrl/Cmd+F)" onClick={() => setFindOpen((v) => !v)}>Find</button>
        {wikilinkTargets && wikilinkTargets.length > 0 && (
          <span className="mde-hint" title={wikilinkTargets.slice(0, 20).join(", ")}>
            [[wikilinks: {wikilinkTargets.length} notes]]
          </span>
        )}
      </div>
      {findOpen && (
        <div className="mde-findbar">
          <span>Press Ctrl/Cmd+F for find, Ctrl/Cmd+H for replace inside the editor.</span>
          <button type="button" onClick={() => { setFindOpen(false); viewRef.current?.focus(); }}>Close</button>
        </div>
      )}
      <div className="mde-editor" ref={hostRef} />
    </div>
  );
}

// Re-export compartment helper for future vim/AI extensions.
export { Compartment };
