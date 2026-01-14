import { useState, useCallback } from 'react';
import { Play, AlertCircle, CheckCircle, Code } from 'lucide-react';

interface EditorProps {
  onAssembled: (binary: Uint8Array) => void;
  assemble: (source: string) => { success: boolean; output?: Uint8Array; error?: string };
  assemblerLoaded: boolean;
}

const DEFAULT_CODE = `; HackVM Assembly
; Press "Assemble & Run" to compile and execute

.equ FRAMEBUFFER, 0x4000
.equ SCREEN_SIZE, 16384
.equ RED, 0xE0

.org 0x0000

start:
    ; Fill screen with red
    MOVI R0, FRAMEBUFFER
    MOVI R1, RED
    MOVI R2, SCREEN_SIZE
    MEMSET
    
    DISPLAY
    HALT
`;

export function Editor({ onAssembled, assemble, assemblerLoaded }: EditorProps) {
  const [source, setSource] = useState(DEFAULT_CODE);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState(false);

  const handleAssemble = useCallback(() => {
    setError(null);
    setSuccess(false);

    const result = assemble(source);
    
    if (result.success && result.output) {
      setSuccess(true);
      onAssembled(result.output);
      setTimeout(() => setSuccess(false), 2000);
    } else {
      setError(result.error || 'Assembly failed');
    }
  }, [source, assemble, onAssembled]);

  return (
    <div className="bg-hvm-panel rounded-xl p-4 border-2 border-hvm-border flex flex-col h-full">
      <div className="flex items-center justify-between mb-3">
        <h3 className="text-hvm-accent text-sm font-semibold uppercase tracking-wider flex items-center gap-2">
          <Code size={16} />
          Assembly Editor
        </h3>
        <button
          onClick={handleAssemble}
          disabled={!assemblerLoaded}
          className="flex items-center gap-2 px-4 py-2 bg-hvm-accent-dim hover:bg-hvm-accent text-black font-medium rounded-lg transition-all disabled:opacity-50 disabled:cursor-not-allowed"
        >
          <Play size={16} />
          Assemble & Run
        </button>
      </div>

      <textarea
        value={source}
        onChange={(e) => setSource(e.target.value)}
        className="flex-1 bg-hvm-input text-gray-100 font-mono text-sm p-3 rounded-lg border border-hvm-border focus:border-hvm-accent focus:outline-none resize-none"
        placeholder="Enter assembly code..."
        spellCheck={false}
      />

      {/* Status Messages */}
      {error && (
        <div className="mt-3 flex items-center gap-2 text-red-400 text-sm bg-red-400/10 px-3 py-2 rounded-lg">
          <AlertCircle size={16} />
          {error}
        </div>
      )}
      
      {success && (
        <div className="mt-3 flex items-center gap-2 text-hvm-accent text-sm bg-hvm-accent/10 px-3 py-2 rounded-lg">
          <CheckCircle size={16} />
          Assembly successful! Program loaded.
        </div>
      )}

      {!assemblerLoaded && (
        <div className="mt-3 text-gray-500 text-sm">
          Loading assembler...
        </div>
      )}
    </div>
  );
}
