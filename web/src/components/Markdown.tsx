import ReactMarkdown from "react-markdown";

const markdownClass = [
  "space-y-3 break-words leading-relaxed",
  "[&_a]:text-accent [&_a]:underline [&_a]:underline-offset-2",
  "[&_code]:rounded [&_code]:border [&_code]:border-border [&_code]:bg-bg [&_code]:px-1 [&_code]:py-px [&_code]:text-[0.85em]",
  "[&_pre]:overflow-x-auto [&_pre]:rounded-lg [&_pre]:border [&_pre]:border-border [&_pre]:bg-bg [&_pre]:p-3 [&_pre_code]:border-0 [&_pre_code]:p-0",
  "[&_h1]:text-lg [&_h1]:font-semibold [&_h1]:tracking-tight [&_h2]:text-base [&_h2]:font-semibold [&_h3]:font-semibold",
  "[&_:is(h1,h2,h3)]:mt-5 [&_:is(h1,h2,h3):first-child]:mt-0",
  "[&_ol]:list-decimal [&_ol]:space-y-1 [&_ol]:pl-5 [&_ul]:list-disc [&_ul]:space-y-1 [&_ul]:pl-5 [&_li]:marker:text-muted",
  "[&_blockquote]:border-l-2 [&_blockquote]:border-border [&_blockquote]:pl-3 [&_blockquote]:text-muted",
  "[&_hr]:border-border",
].join(" ");

export function Markdown({ children }: { children: string }) {
  return (
    <div className={markdownClass}>
      <ReactMarkdown
        components={{
          a: ({ node: _node, ...props }) => <a {...props} target="_blank" rel="noopener noreferrer" />,
        }}
      >{children}</ReactMarkdown>
    </div>
  );
}
