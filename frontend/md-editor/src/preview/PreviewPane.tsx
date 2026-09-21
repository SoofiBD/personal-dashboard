import { useEffect, useMemo, useRef } from "react";
import Markdown, { defaultUrlTransform } from "react-markdown";
import remarkGfm from "remark-gfm";
import remarkMath from "remark-math";
import remarkFlexibleMarkers from "remark-flexible-markers";
import { remarkDefinitionList, defListHastHandlers } from "remark-definition-list";
import remarkSupersub from "../utils/remarkSupersub";
import remarkCustomHeadingId from "../utils/remarkCustomHeadingId";
import rehypeHighlight from "rehype-highlight";
import rehypeRaw from "rehype-raw";
import rehypeSanitize, { defaultSchema } from "rehype-sanitize";
import rehypeKatex from "rehype-katex";
import type { Scroller } from "../utils/scrollSync";
import { MermaidBlock, isMermaidLanguage } from "./MermaidBlock";

export interface PreviewPaneProps {
  content: string;
  assetMap?: Record<string, string>;
  onScrollFraction?: (fraction: number) => void;
  registerScroller?: (scroller: Scroller | null) => void;
  onWikilinkClick?: (target: string) => void;
}

export function PreviewPane({ content, assetMap, onScrollFraction, registerScroller, onWikilinkClick }: PreviewPaneProps) {
  const hostRef = useRef<HTMLDivElement | null>(null);

  useEffect(() => {
    const el = hostRef.current;
    if (!el) return;
    const scroller: Scroller = {
      setFraction: (f: number) => {
        el.scrollTop = f * (el.scrollHeight - el.clientHeight);
      },
    };
    registerScroller?.(scroller);
    const onScroll = () => {
      const max = el.scrollHeight - el.clientHeight;
      onScrollFraction?.(max > 0 ? el.scrollTop / max : 0);
    };
    el.addEventListener("scroll", onScroll, { passive: true });
    return () => {
      el.removeEventListener("scroll", onScroll);
      registerScroller?.(null);
    };
  }, [onScrollFraction, registerScroller]);

  const plugins = useMemo(
    () => ({
      remark: [remarkGfm, remarkMath, remarkFlexibleMarkers, remarkDefinitionList, remarkSupersub, remarkCustomHeadingId],
      rehype: [rehypeRaw, rehypeHighlight, rehypeKatex, [rehypeSanitize, { ...defaultSchema, attributes: { ...defaultSchema.attributes, "*": [...(defaultSchema.attributes?.["*"] ?? []), "className"] } }]],
    }),
    []
  );

  return (
    <div className="mde-preview" ref={hostRef}>
      <Markdown
        remarkPlugins={plugins.remark as never[]}
        rehypePlugins={plugins.rehype as never[]}
        urlTransform={(url) => {
          if (assetMap) {
            const filename = url.split("/").pop() ?? url;
            if (assetMap[filename]) return assetMap[filename];
            if (assetMap[url]) return assetMap[url];
          }
          return defaultUrlTransform(url);
        }}
        components={{
          // eslint-disable-next-line @typescript-eslint/no-unused-vars
          code({ className, children, ...rest }) {
            const lang = /language-(\w+)/.exec(className || "")?.[1] ?? "";
            if (isMermaidLanguage(className)) {
              return <MermaidBlock code={String(children)} />;
            }
            return (
              <code className={className} {...rest}>
                {children}
              </code>
            );
          },
          a({ href, children, ...rest }) {
            const match = /^\[\[(.+)\]\]$/.exec(String(children));
            if (match && onWikilinkClick) {
              return (
                <a
                  href="#"
                  {...rest}
                  onClick={(e) => {
                    e.preventDefault();
                    onWikilinkClick(match[1]);
                  }}
                >
                  {children}
                </a>
              );
            }
            void href;
            return <a {...rest}>{children}</a>;
          },
        }}
      >
        {content}
      </Markdown>
    </div>
  );
}

// Keep hast handlers import referenced for future definition-list styling.
export { defListHastHandlers };
