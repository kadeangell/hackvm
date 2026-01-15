import { useEffect, useRef, useState, useCallback } from 'react';
import { Trash2 } from 'lucide-react';
import { Button } from './ui/button';

interface ConsoleProps {
  output: string;
  onClear: () => void;
  waitingForInput: boolean;
  inputMode: number; // 0=none, 1=GETC, 2=GETS
  onInput: (char: number) => void;
}

export function Console({ output, onClear, waitingForInput, inputMode, onInput }: ConsoleProps) {
  const scrollRef = useRef<HTMLPreElement>(null);
  const inputRef = useRef<HTMLInputElement>(null);
  const [inputValue, setInputValue] = useState('');

  // Auto-scroll to bottom when output changes
  useEffect(() => {
    if (scrollRef.current) {
      scrollRef.current.scrollTop = scrollRef.current.scrollHeight;
    }
  }, [output]);

  // Focus input when waiting for input
  useEffect(() => {
    if (waitingForInput && inputRef.current) {
      inputRef.current.focus();
    }
  }, [waitingForInput]);

  // Handle input change
  const handleInputChange = useCallback((e: React.ChangeEvent<HTMLInputElement>) => {
    const value = e.target.value;

    if (inputMode === 1) {
      // GETC mode - single character, auto-submit
      if (value.length > 0) {
        const char = value.charCodeAt(value.length - 1);
        onInput(char);
        setInputValue('');
      }
    } else {
      // GETS mode - accumulate until Enter
      setInputValue(value);
    }
  }, [inputMode, onInput]);

  // Handle key press for GETS mode
  const handleKeyDown = useCallback((e: React.KeyboardEvent<HTMLInputElement>) => {
    if (inputMode === 2 && e.key === 'Enter') {
      // Send each character including the newline
      for (let i = 0; i < inputValue.length; i++) {
        onInput(inputValue.charCodeAt(i));
      }
      onInput(0x0A); // Newline to complete GETS
      setInputValue('');
      e.preventDefault();
    }
  }, [inputMode, inputValue, onInput]);

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
      {waitingForInput && (
        <div className="mt-2">
          <input
            ref={inputRef}
            type="text"
            value={inputValue}
            onChange={handleInputChange}
            onKeyDown={handleKeyDown}
            placeholder={inputMode === 1 ? "Press any key..." : "Type and press Enter..."}
            className="w-full bg-hvm-input border border-hvm-accent/50 rounded px-2 py-1 font-mono text-xs text-green-400 focus:outline-none focus:border-hvm-accent"
            autoFocus
          />
          <p className="text-gray-500 text-xs mt-1">
            {inputMode === 1 ? "Waiting for character input (GETC)" : "Waiting for line input (GETS)"}
          </p>
        </div>
      )}
    </div>
  );
}
