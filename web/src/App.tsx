import { Zap } from 'lucide-react';
import { useEmulator } from './hooks/useEmulator';
import {
  Screen,
  Controls,
  SpeedControl,
  Registers,
  Flags,
  Stats,
  Status,
} from './components';

export default function App() {
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
    handleKeyDown,
    handleKeyUp,
  } = useEmulator();

  return (
    <div className="min-h-screen p-5">
      <div className="max-w-6xl mx-auto">
        {/* Header */}
        <h1 className="text-center text-4xl font-bold mb-8 flex items-center justify-center gap-3">
          <Zap className="text-hvm-accent" size={40} />
          <span className="text-hvm-accent drop-shadow-[0_0_10px_rgba(0,255,136,0.5)]">
            HackVM Emulator
          </span>
        </h1>

        {/* Main Layout */}
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
              Click on the screen to focus, then use arrow keys and other keys for input.
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
      </div>
    </div>
  );
}
