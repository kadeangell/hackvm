import { useState, useEffect } from 'react';
import Markdown from 'react-markdown';
import remarkGfm from 'remark-gfm';
import { BookOpen, Loader } from 'lucide-react';

export function Docs() {
  const [content, setContent] = useState<string>('');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    fetch('/SPEC.md')
      .then((res) => {
        if (!res.ok) throw new Error('Failed to load documentation');
        return res.text();
      })
      .then((text) => {
        setContent(text);
        setLoading(false);
      })
      .catch((err) => {
        setError(err.message);
        setLoading(false);
      });
  }, []);

  if (loading) {
    return (
      <div className="bg-hvm-panel rounded-xl p-8 border-2 border-hvm-border flex items-center justify-center min-h-[600px]">
        <Loader className="animate-spin text-hvm-accent" size={32} />
      </div>
    );
  }

  if (error) {
    return (
      <div className="bg-hvm-panel rounded-xl p-8 border-2 border-hvm-border">
        <p className="text-red-400">Error: {error}</p>
      </div>
    );
  }

  return (
    <div className="bg-hvm-panel rounded-xl p-6 border-2 border-hvm-border">
      <div className="flex items-center gap-2 mb-4 pb-4 border-b border-hvm-border">
        <BookOpen className="text-hvm-accent" size={20} />
        <h2 className="text-hvm-accent text-lg font-semibold">Documentation</h2>
      </div>
      <div className="prose prose-invert prose-sm max-w-none overflow-auto max-h-[calc(100vh-200px)]
        prose-headings:text-hvm-accent prose-headings:font-semibold
        prose-h1:text-2xl prose-h1:border-b prose-h1:border-hvm-border prose-h1:pb-2
        prose-h2:text-xl prose-h2:mt-8 prose-h2:mb-4
        prose-h3:text-lg prose-h3:mt-6 prose-h3:mb-3
        prose-p:text-gray-300 prose-p:leading-relaxed
        prose-strong:text-hvm-accent
        prose-code:text-green-400 prose-code:bg-hvm-input prose-code:px-1.5 prose-code:py-0.5 prose-code:rounded prose-code:text-sm prose-code:before:content-none prose-code:after:content-none
        prose-pre:bg-hvm-input prose-pre:border prose-pre:border-hvm-border prose-pre:rounded-lg
        prose-a:text-hvm-accent prose-a:no-underline hover:prose-a:underline
        prose-li:text-gray-300
        prose-hr:border-hvm-border
      ">
        <Markdown
          remarkPlugins={[remarkGfm]}
          components={{
            table: ({ children }) => (
              <div className="overflow-x-auto my-4">
                <table className="min-w-full border-collapse border border-hvm-border">
                  {children}
                </table>
              </div>
            ),
            thead: ({ children }) => (
              <thead className="bg-hvm-input">{children}</thead>
            ),
            th: ({ children }) => (
              <th className="border border-hvm-border px-3 py-2 text-left text-hvm-accent font-semibold">
                {children}
              </th>
            ),
            td: ({ children }) => (
              <td className="border border-hvm-border px-3 py-2 text-gray-300">
                {children}
              </td>
            ),
            tr: ({ children }) => (
              <tr className="even:bg-hvm-input/50">{children}</tr>
            ),
          }}
        >
          {content}
        </Markdown>
      </div>
    </div>
  );
}
