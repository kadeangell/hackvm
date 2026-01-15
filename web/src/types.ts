// HackVM WASM exports interface
export interface HackVMExports {
  memory: WebAssembly.Memory;
  init: () => void;
  reset: () => void;
  run: (maxCycles: number) => number;
  isHalted: () => boolean;
  displayRequested: () => boolean;
  getFramebufferPtr: () => number;
  getMemoryPtr: () => number;
  setKeyState: (code: number, pressed: number) => void;
  updateTimers: (deltaMs: number) => void;
  getCyclesExecuted: () => bigint;
  getPC: () => number;
  getSP: () => number;
  getRegister: (index: number) => number;
  getFlags: () => number;
  // Console Output
  getConsoleBufferPtr: () => number;
  getConsoleLength: () => number;
  consumeConsoleUpdate: () => boolean;
  clearConsole: () => void;
  // Console Input
  pushConsoleInput: (ch: number) => void;
  isWaitingForInput: () => boolean;
  getInputMode: () => number;
  clearInput: () => void;
}

export interface EmulatorState {
  running: boolean;
  halted: boolean;
  programLoaded: boolean;
  registers: number[];
  pc: number;
  sp: number;
  flags: {
    z: boolean;
    c: boolean;
    n: boolean;
    v: boolean;
  };
  cycles: bigint;
  fps: number;
  mhz: number;
  consoleOutput: string;
  waitingForInput: boolean;
  inputMode: number; // 0=none, 1=GETC, 2=GETS
}

export const KEY_MAP: Record<string, number> = {
  'ArrowUp': 0x80,
  'ArrowDown': 0x81,
  'ArrowLeft': 0x82,
  'ArrowRight': 0x83,
  'Space': 0x20,
  'Enter': 0x0D,
  'Escape': 0x1B,
  'Backspace': 0x08,
  'Tab': 0x09,
  'ShiftLeft': 0x84,
  'ShiftRight': 0x84,
  'ControlLeft': 0x85,
  'ControlRight': 0x85,
  'AltLeft': 0x86,
  'AltRight': 0x86,
  'F1': 0x90,
  'F2': 0x91,
  'F3': 0x92,
  'F4': 0x93,
  'F5': 0x94,
  'F6': 0x95,
  'F7': 0x96,
  'F8': 0x97,
  'F9': 0x98,
  // Letters A-Z
  ...Object.fromEntries(
    Array.from({ length: 26 }, (_, i) => [`Key${String.fromCharCode(65 + i)}`, 0x41 + i])
  ),
  // Digits 0-9
  ...Object.fromEntries(
    Array.from({ length: 10 }, (_, i) => [`Digit${i}`, 0x30 + i])
  ),
};

export const SPEED_OPTIONS = [
  { label: '0.25x (1 MHz)', value: 0.25 },
  { label: '0.5x (2 MHz)', value: 0.5 },
  { label: '1x (4 MHz)', value: 1 },
  { label: '2x (8 MHz)', value: 2 },
  { label: '4x (16 MHz)', value: 4 },
  { label: 'Unlimited', value: 0 },
];

export const INITIAL_STATE: EmulatorState = {
  running: false,
  halted: false,
  programLoaded: false,
  registers: [0, 0, 0, 0, 0, 0, 0, 0],
  pc: 0,
  sp: 0xFFEF,
  flags: { z: false, c: false, n: false, v: false },
  cycles: BigInt(0),
  fps: 0,
  mhz: 0,
  consoleOutput: '',
  waitingForInput: false,
  inputMode: 0,
};
