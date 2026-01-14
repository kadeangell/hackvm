import { useState, useCallback } from 'react';
import { Zap, Monitor, Code } from 'lucide-react';
import { useEmulator } from './hooks/useEmulator';
import { useAssembler } from './hooks/useAssembler';
import {
  Screen,
  Controls,
  SpeedControl,
  Registers,
  Flags,
  Stats,
  Status,
  Editor,
} from './components';

type Tab = 'emulator' | 'editor';

export default function App() {
  const [activeTab, setActiveTab] = useState<Tab>('editor');

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
  } = useEmulator();

  const { loaded: assemblerLoaded, assemble } = useAssembler();

  const handleAssembled = useCallback((binary: Uint8Array) => {
    loadProgram(binary);
    setActiveTab('emulator');
    // Auto-start after a short delay to let UI update
    setTimeout(() => start(), 100);
  }, [loadProgram, start]);

  const tabClass = (tab: Tab) => `
    flex items-center gap-2 px-6 py-3 font-medium transition-all
    ${activeTab === tab 
      ? 'text-hvm-accent border-b-2 border-hvm-accent' 
      : 'text-gray-400 hover:text-gray-200 border-b-2 border-transparent'}
  `;

  return (
    <div className="min-h-screen p-5">
      <div className="max-w-7xl mx-auto">
        {/* Header */}
        <h1 className="text-center text-4xl font-bold mb-6 flex items-center justify-center gap-3">
          <Zap className="text-hvm-accent" size={40} />
          <span className="text-hvm-accent drop-shadow-[0_0_10px_rgba(0,255,136,0.5)]">
            HackVM
          </span>
        </h1>

        {/* Tabs */}
        <div className="flex justify-center mb-6 border-b border-hvm-border">
          <button className={tabClass('editor')} onClick={() => setActiveTab('editor')}>
            <Code size={20} />
            Editor
          </button>
          <button className={tabClass('emulator')} onClick={() => setActiveTab('emulator')}>
            <Monitor size={20} />
            Emulator
          </button>
        </div>

        {/* Tab Content */}
        {activeTab === 'editor' ? (
          <div className="grid grid-cols-1 lg:grid-cols-[1fr_300px] gap-5">
            <div className="min-h-[600px]">
              <Editor
                onAssembled={handleAssembled}
                assemble={assemble}
                assemblerLoaded={assemblerLoaded}
              />
            </div>
            <div className="space-y-4">
              <div className="bg-hvm-panel rounded-xl p-4 border-2 border-hvm-border">
                <h3 className="text-hvm-accent text-sm font-semibold uppercase tracking-wider mb-3">
                  Quick Reference
                </h3>
                <div className="text-xs text-gray-400 space-y-2 font-mono">
                  <p><span className="text-hvm-accent">Registers:</span> R0-R7</p>
                  <p><span className="text-hvm-accent">Data:</span> MOV, MOVI, LOAD, STORE</p>
                  <p><span className="text-hvm-accent">Math:</span> ADD, SUB, MUL, DIV, INC, DEC</p>
                  <p><span className="text-hvm-accent">Logic:</span> AND, OR, XOR, NOT, SHL, SHR</p>
                  <p><span className="text-hvm-accent">Control:</span> JMP, JZ, JNZ, CALL, RET</p>
                  <p><span className="text-hvm-accent">Memory:</span> MEMSET, MEMCPY</p>
                  <p><span className="text-hvm-accent">System:</span> DISPLAY, HALT</p>
                </div>
              </div>
              <div className="bg-hvm-panel rounded-xl p-4 border-2 border-hvm-border">
                <h3 className="text-hvm-accent text-sm font-semibold uppercase tracking-wider mb-3">
                  Directives
                </h3>
                <div className="text-xs text-gray-400 space-y-1 font-mono">
                  <p>.equ NAME, value</p>
                  <p>.org address</p>
                  <p>.db byte, byte, ...</p>
                  <p>.dw word, word, ...</p>
                  <p>.ds count</p>
                </div>
              </div>
              <div className="bg-hvm-panel rounded-xl p-4 border-2 border-hvm-border">
                <h3 className="text-hvm-accent text-sm font-semibold uppercase tracking-wider mb-3">
                  Memory Map
                </h3>
                <div className="text-xs text-gray-400 space-y-1 font-mono">
                  <p>0x0000 - Program</p>
                  <p>0x4000 - Framebuffer</p>
                  <p>0x8000 - RAM</p>
                  <p>0xFFF0 - Timer</p>
                  <p>0xFFF4 - Keyboard</p>
                </div>
              </div>
            </div>
          </div>
        ) : (
          <div className="grid grid-cols-1 lg:grid-cols-[1fr_350px] gap-5">
            {/* Screen Section */}
            <div className="bg-hvm-panel rounded-xl p-5 border-2 border-hvm-border">
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

              <p className="text-xs text-gray-500 text-center mt-4">
                Click on the screen to focus, then use arrow keys for input.
              </p>
            </div>

            {/* Sidebar */}
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
        )}
      </div>
    </div>
  );
}
