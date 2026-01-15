import { useEffect, useRef } from 'react';
import { Trash2 } from 'lucide-react';
import { Button } from './ui/button';

interface ConsoleProps {
  output: string;
  onClear: () => void;
}

export function Console({ output, onClear }: ConsoleProps) {
  const scrollRef = useRef<HTMLPreElement>(null);

  // Auto-scroll to bottom when output changes
  useEffect(() => {
    if (scrollRef.current) {
      scrollRef.current.scrollTop = scrollRef.current.scrollHeight;
    }
  }, [output]);

  return (
    <div className="mt-4">
      <div className="flex items-center justify-between mb-2">
        <h3 className="text-hvm-accent text-sm font-semibold uppercase tracking-wider">Console</h3>
        <Button variant="ghost" size="icon" onClick={onClear} title="Clear console">
          <Trash2 size={14} />
        </Button>
      </div>
      <pre
        ref={scrollRef}
        className="bg-hvm-input rounded p-2 font-mono text-xs text-green-400 h-32 overflow-y-auto whitespace-pre-wrap break-all"
      >
        {output || <span className="text-gray-600 italic">No output</span>}
      </pre>
    </div>
  );
}
