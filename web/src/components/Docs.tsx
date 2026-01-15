import { useState, useEffect, useMemo, useCallback } from 'react';
import Markdown from 'react-markdown';
import remarkGfm from 'remark-gfm';
import { BookOpen, Loader, ChevronRight, Copy, Check } from 'lucide-react';

// Simple syntax highlighter for assembly and common code
function highlightCode(code: string, language: string): JSX.Element[] {
  const lines = code.split('\n');

  return lines.map((line, lineIndex) => {
    const tokens: JSX.Element[] = [];
    let remaining = line;
    let keyIndex = 0;

    const addToken = (text: string, className?: string) => {
      if (text) {
        tokens.push(
          <span key={keyIndex++} className={className}>
            {text}
          </span>
        );
      }
    };

    if (language === 'asm' || language === 'assembly' || language === '') {
      // Assembly syntax highlighting
      while (remaining.length > 0) {
        // Comments (starting with ;)
        const commentMatch = remaining.match(/^(;.*)$/);
        if (commentMatch) {
          addToken(commentMatch[1], 'text-gray-500 italic');
          remaining = '';
          continue;
        }

        // Labels (word followed by :)
        const labelMatch = remaining.match(/^(\w+:)/);
        if (labelMatch) {
          addToken(labelMatch[1], 'text-yellow-400');
          remaining = remaining.slice(labelMatch[1].length);
          continue;
        }

        // Directives (.db, .dw, etc.)
        const directiveMatch = remaining.match(/^(\.\w+)/);
        if (directiveMatch) {
          addToken(directiveMatch[1], 'text-purple-400');
          remaining = remaining.slice(directiveMatch[1].length);
          continue;
        }

        // Registers (R0-R7, SP, PC)
        const registerMatch = remaining.match(/^(R[0-7]|SP|PC)\b/i);
        if (registerMatch) {
          addToken(registerMatch[1], 'text-blue-400');
          remaining = remaining.slice(registerMatch[1].length);
          continue;
        }

        // Hex numbers
        const hexMatch = remaining.match(/^(0x[0-9A-Fa-f]+)/);
        if (hexMatch) {
          addToken(hexMatch[1], 'text-orange-400');
          remaining = remaining.slice(hexMatch[1].length);
          continue;
        }

        // Decimal numbers
        const numMatch = remaining.match(/^(\d+)/);
        if (numMatch) {
          addToken(numMatch[1], 'text-orange-400');
          remaining = remaining.slice(numMatch[1].length);
          continue;
        }

        // Strings
        const stringMatch = remaining.match(/^("[^"]*"|'[^']*')/);
        if (stringMatch) {
          addToken(stringMatch[1], 'text-green-400');
          remaining = remaining.slice(stringMatch[1].length);
          continue;
        }

        // Instructions (uppercase words at start or after whitespace)
        const instrMatch = remaining.match(/^([A-Z]{2,})\b/);
        if (instrMatch) {
          addToken(instrMatch[1], 'text-cyan-400 font-semibold');
          remaining = remaining.slice(instrMatch[1].length);
          continue;
        }

        // Default: take one character
        addToken(remaining[0]);
        remaining = remaining.slice(1);
      }
    } else {
      // Generic highlighting for other languages
      while (remaining.length > 0) {
        // Comments
        const commentMatch = remaining.match(/^(\/\/.*|#.*)$/);
        if (commentMatch) {
          addToken(commentMatch[1], 'text-gray-500 italic');
          remaining = '';
          continue;
        }

        // Strings
        const stringMatch = remaining.match(/^("[^"]*"|'[^']*'|`[^`]*`)/);
        if (stringMatch) {
          addToken(stringMatch[1], 'text-green-400');
          remaining = remaining.slice(stringMatch[1].length);
          continue;
        }

        // Numbers
        const numMatch = remaining.match(/^(0x[0-9A-Fa-f]+|\d+\.?\d*)/);
        if (numMatch) {
          addToken(numMatch[1], 'text-orange-400');
          remaining = remaining.slice(numMatch[1].length);
          continue;
        }

        // Keywords
        const keywordMatch = remaining.match(/^(const|let|var|function|return|if|else|for|while|import|export|from|class|interface|type)\b/);
        if (keywordMatch) {
          addToken(keywordMatch[1], 'text-purple-400');
          remaining = remaining.slice(keywordMatch[1].length);
          continue;
        }

        // Default
        addToken(remaining[0]);
        remaining = remaining.slice(1);
      }
    }

    return (
      <span key={lineIndex}>
        {tokens}
        {lineIndex < lines.length - 1 && '\n'}
      </span>
    );
  });
}

// Code block component with copy button
function CodeBlock({ children, className }: { children: string; className?: string }) {
  const [copied, setCopied] = useState(false);
  const language = className?.replace('language-', '') || '';
  const code = String(children).replace(/\n$/, '');

  const handleCopy = async () => {
    await navigator.clipboard.writeText(code);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  return (
    <div className="relative group">
      <button
        onClick={handleCopy}
        className="absolute right-2 top-2 p-1.5 rounded bg-hvm-border/50 text-gray-400
                   opacity-0 group-hover:opacity-100 transition-opacity hover:bg-hvm-border hover:text-gray-200"
        title="Copy code"
      >
        {copied ? <Check size={14} className="text-green-400" /> : <Copy size={14} />}
      </button>
      <pre className="bg-hvm-input border border-hvm-border rounded-lg p-4 overflow-x-auto">
        <code className="text-sm font-mono">{highlightCode(code, language)}</code>
      </pre>
    </div>
  );
}

interface TocEntry {
  id: string;
  title: string;
  level: number;
}

function generateId(text: string): string {
  return text
    .toLowerCase()
    .replace(/[^\w\s-]/g, '')
    .replace(/\s+/g, '-')
    .replace(/^-+|-+$/g, '');
}

function extractToc(markdown: string): TocEntry[] {
  const entries: TocEntry[] = [];
  const lines = markdown.split('\n');

  for (const line of lines) {
    const match = line.match(/^(#{1,3})\s+(.+)$/);
    if (match) {
      const level = match[1].length;
      const title = match[2].trim();
      // Skip the main title and table of contents section
      if (title === 'HackVM: Instruction Set Architecture & System Design Specification') continue;
      if (title === 'Table of Contents') continue;

      entries.push({
        id: generateId(title),
        title,
        level,
      });
    }
  }

  return entries;
}

function removeTableOfContentsSection(markdown: string): string {
  // Remove the table of contents section from the markdown
  const tocStart = markdown.indexOf('## Table of Contents');
  if (tocStart === -1) return markdown;

  // Find the next section (starts with ## and a number)
  const afterToc = markdown.substring(tocStart + 20);
  const nextSection = afterToc.search(/\n---\n\n## \d/);

  if (nextSection === -1) return markdown;

  return markdown.substring(0, tocStart) + afterToc.substring(nextSection + 1);
}

export function Docs() {
  const [content, setContent] = useState<string>('');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [activeSection, setActiveSection] = useState<string>('');

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

  const toc = useMemo(() => extractToc(content), [content]);
  const processedContent = useMemo(() => removeTableOfContentsSection(content), [content]);
  const [contentRendered, setContentRendered] = useState(false);

  // Mark content as rendered after markdown processes
  useEffect(() => {
    if (processedContent) {
      // Give React time to render the markdown
      const timer = setTimeout(() => setContentRendered(true), 100);
      return () => clearTimeout(timer);
    }
  }, [processedContent]);

  // Calculate which section is active based on scroll position
  const updateActiveSection = useCallback(() => {
    if (!toc.length || !contentRendered) return;

    const scrollTop = window.scrollY;
    const offset = 100; // Account for any fixed headers or margin

    // Find the heading that's currently at or above the scroll position
    let currentSection = toc[0]?.id || '';

    for (const { id } of toc) {
      const element = document.getElementById(id);
      if (element) {
        const rect = element.getBoundingClientRect();
        const absoluteTop = rect.top + scrollTop;

        if (absoluteTop <= scrollTop + offset) {
          currentSection = id;
        } else {
          break;
        }
      }
    }

    setActiveSection(currentSection);
  }, [toc, contentRendered]);

  // Track active section based on scroll position
  useEffect(() => {
    if (!contentRendered) return;

    // Initial update
    updateActiveSection();

    // Update on scroll
    window.addEventListener('scroll', updateActiveSection, { passive: true });
    return () => window.removeEventListener('scroll', updateActiveSection);
  }, [contentRendered, updateActiveSection]);

  const scrollToSection = (id: string) => {
    const element = document.getElementById(id);
    if (element) {
      element.scrollIntoView({ behavior: 'smooth', block: 'start' });
      setActiveSection(id);
    }
  };

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
    <div className="flex gap-5">
      {/* Sidebar with Table of Contents */}
      <aside className="hidden lg:block w-72 flex-shrink-0">
        <div className="bg-hvm-panel rounded-xl border-2 border-hvm-border sticky top-5 max-h-[calc(100vh-60px)] overflow-hidden flex flex-col">
          <div className="flex items-center gap-2 p-4 border-b border-hvm-border flex-shrink-0">
            <BookOpen className="text-hvm-accent" size={18} />
            <h3 className="text-hvm-accent font-semibold text-sm">Contents</h3>
          </div>
          <nav className="overflow-y-auto flex-1 p-2">
            <ul className="space-y-0.5">
              {toc.map(({ id, title, level }) => (
                <li key={id}>
                  <button
                    onClick={() => scrollToSection(id)}
                    className={`
                      w-full text-left px-2 py-1.5 rounded text-xs transition-colors
                      flex items-center gap-1
                      ${level === 2 ? 'pl-2' : level === 3 ? 'pl-5' : 'pl-2'}
                      ${activeSection === id
                        ? 'bg-hvm-accent/20 text-hvm-accent'
                        : 'text-gray-400 hover:text-gray-200 hover:bg-hvm-input/50'}
                    `}
                  >
                    {level === 3 && (
                      <ChevronRight size={10} className="flex-shrink-0 opacity-50" />
                    )}
                    <span className="truncate">{title}</span>
                  </button>
                </li>
              ))}
            </ul>
          </nav>
        </div>
      </aside>

      {/* Main Content */}
      <main className="flex-1 min-w-0">
        <div className="bg-hvm-panel rounded-xl p-6 border-2 border-hvm-border">
          <div className="flex items-center gap-2 mb-4 pb-4 border-b border-hvm-border lg:hidden">
            <BookOpen className="text-hvm-accent" size={20} />
            <h2 className="text-hvm-accent text-lg font-semibold">Documentation</h2>
          </div>
          <div className="prose prose-invert prose-sm max-w-none
            prose-headings:text-hvm-accent prose-headings:font-semibold prose-headings:scroll-mt-4
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
                // Generate IDs for headings
                h1: ({ children }) => {
                  const text = String(children);
                  const id = generateId(text);
                  return <h1 id={id}>{children}</h1>;
                },
                h2: ({ children }) => {
                  const text = String(children);
                  const id = generateId(text);
                  return <h2 id={id}>{children}</h2>;
                },
                h3: ({ children }) => {
                  const text = String(children);
                  const id = generateId(text);
                  return <h3 id={id}>{children}</h3>;
                },
                // Table components
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
                // Code blocks with syntax highlighting and copy button
                code: ({ children, className, ...props }) => {
                  // Check if this is a code block (inside pre) or inline code
                  const isBlock = className?.startsWith('language-') ||
                    (typeof children === 'string' && children.includes('\n'));

                  if (isBlock) {
                    return <CodeBlock className={className}>{String(children)}</CodeBlock>;
                  }

                  // Inline code
                  return (
                    <code className="text-green-400 bg-hvm-input px-1.5 py-0.5 rounded text-sm" {...props}>
                      {children}
                    </code>
                  );
                },
                // Override pre to avoid double wrapping
                pre: ({ children }) => <>{children}</>,
                // Transform internal links to use scroll behavior
                a: ({ href, children }) => {
                  if (href?.startsWith('#')) {
                    const targetId = href.slice(1);
                    // Map the original link format to our generated IDs
                    const mappedId = mapLinkToId(targetId);
                    return (
                      <button
                        onClick={() => scrollToSection(mappedId)}
                        className="text-hvm-accent hover:underline"
                      >
                        {children}
                      </button>
                    );
                  }
                  return (
                    <a href={href} className="text-hvm-accent hover:underline">
                      {children}
                    </a>
                  );
                },
              }}
            >
              {processedContent}
            </Markdown>
          </div>
        </div>
      </main>
    </div>
  );
}

// Map original link anchors (like "1-overview") to our generated IDs
function mapLinkToId(originalAnchor: string): string {
  // The original anchors are like "1-overview", "2-system-architecture"
  // Our IDs are generated from the heading text like "1-overview", "2-system-architecture"
  // So they should mostly match, but let's handle edge cases
  return originalAnchor;
}
