import { useState, useCallback, useRef, useEffect } from 'react';
import { Play, AlertCircle, CheckCircle, Code } from 'lucide-react';
import MonacoEditor, { OnMount, BeforeMount } from '@monaco-editor/react';
import type { editor } from 'monaco-editor';
// @ts-expect-error - monaco-vim doesn't have types
import { initVimMode } from 'monaco-vim';

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

// Register HackVM assembly language for Monaco
const registerHackVMLanguage: BeforeMount = (monaco) => {
  // Register the language
  monaco.languages.register({ id: 'hackvm-asm' });

  // Define tokens for syntax highlighting
  monaco.languages.setMonarchTokensProvider('hackvm-asm', {
    ignoreCase: true,

    keywords: [
      'NOP', 'HALT', 'DISPLAY', 'RET', 'PUSHF', 'POPF',
      'MOV', 'MOVI', 'LOAD', 'LOADB', 'STORE', 'STOREB', 'PUSH', 'POP',
      'ADD', 'ADDI', 'SUB', 'SUBI', 'MUL', 'DIV', 'INC', 'DEC', 'NEG',
      'AND', 'ANDI', 'OR', 'ORI', 'XOR', 'XORI', 'NOT',
      'SHL', 'SHLI', 'SHR', 'SHRI', 'SAR', 'SARI',
      'CMP', 'CMPI', 'TEST', 'TESTI',
      'JMP', 'JMPR', 'JZ', 'JE', 'JNZ', 'JNE', 'JC', 'JB', 'JNC', 'JAE',
      'JN', 'JS', 'JNN', 'JNS', 'JO', 'JNO', 'JA', 'JBE', 'JG', 'JGE', 'JL', 'JLE',
      'CALL', 'CALLR', 'MEMCPY', 'MEMSET'
    ],

    directives: ['org', 'equ', 'db', 'dw', 'ds'],

    registers: ['R0', 'R1', 'R2', 'R3', 'R4', 'R5', 'R6', 'R7'],

    tokenizer: {
      root: [
        // Comments
        [/;.*$/, 'comment'],

        // Directives (starting with .)
        [/\.[a-zA-Z]+/, {
          cases: {
            '@directives': 'keyword.directive',
            '@default': 'identifier'
          }
        }],

        // Labels (identifier followed by colon)
        [/[a-zA-Z_][a-zA-Z0-9_]*:/, 'type.identifier'],

        // Registers
        [/[rR][0-7]/, 'variable.predefined'],

        // Hex numbers
        [/0[xX][0-9a-fA-F]+/, 'number.hex'],

        // Binary numbers
        [/0[bB][01]+/, 'number.binary'],

        // Decimal numbers
        [/\d+/, 'number'],

        // String literals
        [/"[^"]*"/, 'string'],

        // Character literals
        [/'[^']*'/, 'string'],

        // Instructions (keywords)
        [/[a-zA-Z_][a-zA-Z0-9_]*/, {
          cases: {
            '@keywords': 'keyword',
            '@default': 'identifier'
          }
        }],

        // Punctuation
        [/[,\[\]]/, 'delimiter'],
      ]
    }
  });

  // Define editor theme matching HackVM colors
  monaco.editor.defineTheme('hackvm-dark', {
    base: 'vs-dark',
    inherit: true,
    rules: [
      { token: 'comment', foreground: '6A9955', fontStyle: 'italic' },
      { token: 'keyword', foreground: '00ff88', fontStyle: 'bold' },
      { token: 'keyword.directive', foreground: 'C586C0' },
      { token: 'type.identifier', foreground: 'DCDCAA' },
      { token: 'variable.predefined', foreground: '9CDCFE' },
      { token: 'number', foreground: 'B5CEA8' },
      { token: 'number.hex', foreground: 'B5CEA8' },
      { token: 'number.binary', foreground: 'B5CEA8' },
      { token: 'string', foreground: 'CE9178' },
      { token: 'identifier', foreground: '9CDCFE' },
      { token: 'delimiter', foreground: 'D4D4D4' },
    ],
    colors: {
      'editor.background': '#0f0f1a',
      'editor.foreground': '#D4D4D4',
      'editor.lineHighlightBackground': '#1a1a2e',
      'editor.selectionBackground': '#264f78',
      'editorCursor.foreground': '#00ff88',
      'editorLineNumber.foreground': '#4a4a6a',
      'editorLineNumber.activeForeground': '#00ff88',
    }
  });

  // Register completion provider
  monaco.languages.registerCompletionItemProvider('hackvm-asm', {
    provideCompletionItems: (model, position) => {
      const word = model.getWordUntilPosition(position);
      const range = {
        startLineNumber: position.lineNumber,
        endLineNumber: position.lineNumber,
        startColumn: word.startColumn,
        endColumn: word.endColumn
      };

      const instructions = [
        'NOP', 'HALT', 'DISPLAY', 'RET', 'PUSHF', 'POPF',
        'MOV', 'MOVI', 'LOAD', 'LOADB', 'STORE', 'STOREB', 'PUSH', 'POP',
        'ADD', 'ADDI', 'SUB', 'SUBI', 'MUL', 'DIV', 'INC', 'DEC', 'NEG',
        'AND', 'ANDI', 'OR', 'ORI', 'XOR', 'XORI', 'NOT',
        'SHL', 'SHLI', 'SHR', 'SHRI', 'SAR', 'SARI',
        'CMP', 'CMPI', 'TEST', 'TESTI',
        'JMP', 'JMPR', 'JZ', 'JNZ', 'JC', 'JNC', 'JN', 'JNN', 'JO', 'JNO',
        'JA', 'JBE', 'JG', 'JGE', 'JL', 'JLE',
        'CALL', 'CALLR', 'MEMCPY', 'MEMSET'
      ];

      const directives = ['.org', '.equ', '.db', '.dw', '.ds'];
      const registers = ['R0', 'R1', 'R2', 'R3', 'R4', 'R5', 'R6', 'R7'];

      const suggestions = [
        ...instructions.map(instr => ({
          label: instr,
          kind: monaco.languages.CompletionItemKind.Keyword,
          insertText: instr,
          range
        })),
        ...directives.map(dir => ({
          label: dir,
          kind: monaco.languages.CompletionItemKind.Keyword,
          insertText: dir.substring(1), // Remove leading dot for insertion after .
          range
        })),
        ...registers.map(reg => ({
          label: reg,
          kind: monaco.languages.CompletionItemKind.Variable,
          insertText: reg,
          range
        }))
      ];

      return { suggestions };
    }
  });
};

export function Editor({ onAssembled, assemble, assemblerLoaded }: EditorProps) {
  const [source, setSource] = useState(DEFAULT_CODE);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState(false);
  const [vimEnabled, setVimEnabled] = useState(false);

  const editorRef = useRef<editor.IStandaloneCodeEditor | null>(null);
  const vimModeRef = useRef<{ dispose: () => void } | null>(null);
  const statusBarRef = useRef<HTMLDivElement | null>(null);

  const handleEditorMount: OnMount = (editor) => {
    editorRef.current = editor;
  };

  // Handle vim mode toggle
  useEffect(() => {
    if (!editorRef.current || !statusBarRef.current) return;

    if (vimEnabled) {
      // Initialize vim mode
      vimModeRef.current = initVimMode(editorRef.current, statusBarRef.current);
    } else {
      // Dispose vim mode
      if (vimModeRef.current) {
        vimModeRef.current.dispose();
        vimModeRef.current = null;
      }
    }

    return () => {
      if (vimModeRef.current) {
        vimModeRef.current.dispose();
        vimModeRef.current = null;
      }
    };
  }, [vimEnabled]);

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
        <div className="flex items-center gap-3">
          {/* Vim Mode Toggle */}
          <button
            onClick={() => setVimEnabled(!vimEnabled)}
            className={`px-3 py-1.5 text-xs font-medium rounded-md transition-all border ${
              vimEnabled
                ? 'bg-hvm-accent/20 text-hvm-accent border-hvm-accent'
                : 'bg-hvm-input text-gray-400 border-hvm-border hover:border-gray-500'
            }`}
            title={vimEnabled ? 'Disable Vim mode' : 'Enable Vim mode'}
          >
            VIM {vimEnabled ? 'ON' : 'OFF'}
          </button>

          <button
            onClick={handleAssemble}
            disabled={!assemblerLoaded}
            className="flex items-center gap-2 px-4 py-2 bg-hvm-accent-dim hover:bg-hvm-accent text-black font-medium rounded-lg transition-all disabled:opacity-50 disabled:cursor-not-allowed"
          >
            <Play size={16} />
            Assemble & Run
          </button>
        </div>
      </div>

      <div className="flex-1 rounded-lg overflow-hidden border border-hvm-border min-h-[400px]">
        <MonacoEditor
          height="100%"
          language="hackvm-asm"
          theme="hackvm-dark"
          value={source}
          onChange={(value) => setSource(value || '')}
          beforeMount={registerHackVMLanguage}
          onMount={handleEditorMount}
          options={{
            fontSize: 14,
            fontFamily: "'JetBrains Mono', 'Fira Code', Consolas, monospace",
            minimap: { enabled: false },
            scrollBeyondLastLine: false,
            lineNumbers: 'on',
            glyphMargin: false,
            folding: false,
            lineDecorationsWidth: 10,
            lineNumbersMinChars: 3,
            renderLineHighlight: 'line',
            selectOnLineNumbers: true,
            automaticLayout: true,
            tabSize: 4,
            insertSpaces: true,
            wordWrap: 'off',
            contextmenu: true,
            quickSuggestions: true,
            suggestOnTriggerCharacters: true,
            cursorBlinking: vimEnabled ? 'solid' : 'blink',
          }}
        />
      </div>

      {/* Vim Status Bar */}
      <div
        ref={statusBarRef}
        className={`h-6 mt-1 px-2 font-mono text-sm flex items-center rounded transition-all ${
          vimEnabled ? 'bg-hvm-input text-hvm-accent' : 'hidden'
        }`}
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
