import { useCallback } from 'react';
import { Routes, Route, NavLink, Navigate, useNavigate } from 'react-router-dom';
import { Zap, Monitor, Code, BookOpen } from 'lucide-react';
import { useEmulator } from './hooks/useEmulator';
import { useAssembler } from './hooks/useAssembler';
import { Card, CardHeader, CardTitle, CardContent } from './components/ui/card';
import {
  Screen,
  Controls,
  SpeedControl,
  Registers,
  Flags,
  Stats,
  Status,
  Editor,
  Docs,
  Console,
} from './components';

function EditorPage({
  onAssembled,
  assemble,
  assemblerLoaded
}: {
  onAssembled: (binary: Uint8Array) => void;
  assemble: (source: string) => { success: boolean; output?: Uint8Array; error?: string };
  assemblerLoaded: boolean;
}) {
  return (
    <div className="grid grid-cols-1 lg:grid-cols-[1fr_300px] gap-5">
      <div className="min-h-[600px]">
        <Editor
          onAssembled={onAssembled}
          assemble={assemble}
          assemblerLoaded={assemblerLoaded}
        />
      </div>
      <div className="space-y-4">
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm uppercase tracking-wider">Quick Reference</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-xs text-gray-400 space-y-2 font-mono">
              <p><span className="text-hvm-accent">Registers:</span> R0-R7</p>
              <p><span className="text-hvm-accent">Data:</span> MOV, MOVI, LOAD, STORE</p>
              <p><span className="text-hvm-accent">Math:</span> ADD, SUB, MUL, DIV, INC, DEC</p>
              <p><span className="text-hvm-accent">Logic:</span> AND, OR, XOR, NOT, SHL, SHR</p>
              <p><span className="text-hvm-accent">Control:</span> JMP, JZ, JNZ, CALL, RET</p>
              <p><span className="text-hvm-accent">Memory:</span> MEMSET, MEMCPY</p>
              <p><span className="text-hvm-accent">System:</span> DISPLAY, HALT</p>
            </div>
          </CardContent>
        </Card>
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm uppercase tracking-wider">Directives</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-xs text-gray-400 space-y-1 font-mono">
              <p>.equ NAME, value</p>
              <p>.org address</p>
              <p>.db byte, byte, ...</p>
              <p>.dw word, word, ...</p>
              <p>.ds count</p>
            </div>
          </CardContent>
        </Card>
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm uppercase tracking-wider">Memory Map</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-xs text-gray-400 space-y-1 font-mono">
              <p>0x0000 - Program</p>
              <p>0x4000 - Framebuffer</p>
              <p>0x8000 - RAM</p>
              <p>0xFFF0 - Timer</p>
              <p>0xFFF4 - Keyboard</p>
            </div>
          </CardContent>
        </Card>
      </div>
    </div>
  );
}

function EmulatorPage({
  state,
  wasmLoaded,
  speedMultiplier,
  setSpeedMultiplier,
  initCanvas,
  start,
  pause,
  step,
  reset,
  loadFile,
  handleKeyDown,
  handleKeyUp,
  clearConsole,
}: {
  state: {
    running: boolean;
    halted: boolean;
    programLoaded: boolean;
    registers: number[];
    pc: number;
    sp: number;
    flags: { z: boolean; c: boolean; n: boolean; v: boolean };
    cycles: bigint;
    fps: number;
    mhz: number;
    consoleOutput: string;
  };
  wasmLoaded: boolean;
  speedMultiplier: number;
  setSpeedMultiplier: (value: number) => void;
  initCanvas: (canvas: HTMLCanvasElement) => void;
  start: () => void;
  pause: () => void;
  step: () => void;
  reset: () => void;
  loadFile: (file: File) => void;
  handleKeyDown: (e: KeyboardEvent) => void;
  handleKeyUp: (e: KeyboardEvent) => void;
  clearConsole: () => void;
}) {
  return (
    <div className="grid grid-cols-1 lg:grid-cols-[1fr_350px] gap-5">
      <Card className="p-5">
        <Screen
          onInit={initCanvas}
          onKeyDown={handleKeyDown}
          onKeyUp={handleKeyUp}
        />

        <Controls
          running={state.running}
          halted={state.halted}
          programLoaded={state.programLoaded}
          onStart={start}
          onPause={pause}
          onStep={step}
          onReset={reset}
          onLoadFile={loadFile}
        />

        <SpeedControl
          value={speedMultiplier}
          onChange={setSpeedMultiplier}
        />

        <Console
          output={state.consoleOutput}
          onClear={clearConsole}
        />
      </Card>

      <div className="flex flex-col gap-4">
        <Status
          running={state.running}
          halted={state.halted}
          programLoaded={state.programLoaded}
          wasmLoaded={wasmLoaded}
        />

        <Registers
          registers={state.registers}
          pc={state.pc}
          sp={state.sp}
        />

        <Flags flags={state.flags} />

        <Stats
          cycles={state.cycles}
          fps={state.fps}
          mhz={state.mhz}
        />
      </div>
    </div>
  );
}

export default function App() {
  const navigate = useNavigate();

  const {
    state,
    wasmLoaded,
    speedMultiplier,
    setSpeedMultiplier,
    initCanvas,
    start,
    pause,
    step,
    reset,
    loadFile,
    loadProgram,
    handleKeyDown,
    handleKeyUp,
    clearConsole,
  } = useEmulator();

  const { loaded: assemblerLoaded, assemble } = useAssembler();

  const handleAssembled = useCallback((binary: Uint8Array) => {
    loadProgram(binary);
    navigate('/emulator');
    setTimeout(() => start(), 100);
  }, [loadProgram, navigate, start]);

  const navLinkClass = ({ isActive }: { isActive: boolean }) => `
    flex items-center gap-2 px-6 py-3 font-medium transition-all
    ${isActive
      ? 'text-hvm-accent border-b-2 border-hvm-accent'
      : 'text-gray-400 hover:text-gray-200 border-b-2 border-transparent'}
  `;

  return (
    <div className="min-h-screen p-5">
      <div className="max-w-7xl mx-auto">
        <h1 className="text-center text-4xl font-bold mb-6 flex items-center justify-center gap-3">
          <Zap className="text-hvm-accent" size={40} />
          <span className="text-hvm-accent drop-shadow-[0_0_10px_rgba(0,255,136,0.5)]">
            HackVM
          </span>
        </h1>

        <div className="flex justify-center mb-6 border-b border-hvm-border">
          <NavLink to="/editor" className={navLinkClass}>
            <Code size={20} />
            Editor
          </NavLink>
          <NavLink to="/emulator" className={navLinkClass}>
            <Monitor size={20} />
            Emulator
          </NavLink>
          <NavLink to="/docs" className={navLinkClass}>
            <BookOpen size={20} />
            Docs
          </NavLink>
        </div>

        <Routes>
          <Route path="/" element={<Navigate to="/editor" replace />} />
          <Route
            path="/editor"
            element={
              <EditorPage
                onAssembled={handleAssembled}
                assemble={assemble}
                assemblerLoaded={assemblerLoaded}
              />
            }
          />
          <Route
            path="/emulator"
            element={
              <EmulatorPage
                state={state}
                wasmLoaded={wasmLoaded}
                speedMultiplier={speedMultiplier}
                setSpeedMultiplier={setSpeedMultiplier}
                initCanvas={initCanvas}
                start={start}
                pause={pause}
                step={step}
                reset={reset}
                loadFile={loadFile}
                handleKeyDown={handleKeyDown}
                handleKeyUp={handleKeyUp}
                clearConsole={clearConsole}
              />
            }
          />
          <Route path="/docs" element={<Docs />} />
        </Routes>
      </div>
    </div>
  );
}
