import { useRef, useState, useCallback, useEffect } from 'react';
import { HackVMExports, EmulatorState, KEY_MAP, INITIAL_STATE } from '../types';

export function useEmulator() {
  const wasmRef = useRef<HackVMExports | null>(null);
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const imageDataRef = useRef<ImageData | null>(null);
  const animationFrameRef = useRef<number | null>(null);
  const loadedProgramRef = useRef<Uint8Array | null>(null);
  
  const [state, setState] = useState<EmulatorState>(INITIAL_STATE);
  const [speedMultiplier, setSpeedMultiplier] = useState(1);
  const [wasmLoaded, setWasmLoaded] = useState(false);
  
  // Stats tracking refs
  const lastTimestampRef = useRef(0);
  const lastFpsUpdateRef = useRef(0);
  const frameCountRef = useRef(0);
  const cyclesThisSecondRef = useRef(0);
  const cycleDebtRef = useRef(0);

  // Load WASM on mount
  useEffect(() => {
    async function loadWasm() {
      try {
        const response = await fetch('/hackvm.wasm');
        const bytes = await response.arrayBuffer();
        const { instance } = await WebAssembly.instantiate(bytes, { env: {} });
        wasmRef.current = instance.exports as unknown as HackVMExports;
        wasmRef.current.init();
        setWasmLoaded(true);
      } catch (error) {
        console.error('Failed to load WASM:', error);
      }
    }
    loadWasm();
  }, []);

  // Initialize canvas
  const initCanvas = useCallback((canvas: HTMLCanvasElement) => {
    canvasRef.current = canvas;
    const ctx = canvas.getContext('2d');
    if (ctx) {
      imageDataRef.current = ctx.createImageData(128, 128);
    }
  }, []);

  // Render framebuffer to canvas
  const renderFramebuffer = useCallback(() => {
    const wasm = wasmRef.current;
    const canvas = canvasRef.current;
    const imageData = imageDataRef.current;
    
    if (!wasm || !canvas || !imageData) return;
    
    const ctx = canvas.getContext('2d');
    if (!ctx) return;
    
    const fbPtr = wasm.getFramebufferPtr();
    const fb = new Uint8Array(wasm.memory.buffer, fbPtr, 16384);
    const pixels = imageData.data;
    
    for (let i = 0; i < 16384; i++) {
      const rgb332 = fb[i];
      const r3 = (rgb332 >> 5) & 0x07;
      const g3 = (rgb332 >> 2) & 0x07;
      const b2 = rgb332 & 0x03;
      
      const idx = i * 4;
      pixels[idx] = Math.round(r3 * 255 / 7);
      pixels[idx + 1] = Math.round(g3 * 255 / 7);
      pixels[idx + 2] = Math.round(b2 * 255 / 3);
      pixels[idx + 3] = 255;
    }
    
    ctx.putImageData(imageData, 0, 0);
  }, []);

  // Read console output from WASM
  const updateConsole = useCallback(() => {
    const wasm = wasmRef.current;
    if (!wasm || !wasm.consumeConsoleUpdate()) return;

    const ptr = wasm.getConsoleBufferPtr();
    const len = wasm.getConsoleLength();
    const buffer = new Uint8Array(wasm.memory.buffer, ptr, len);
    const text = new TextDecoder().decode(buffer);

    setState(prev => ({ ...prev, consoleOutput: text }));
  }, []);

  // Clear console output
  const clearConsole = useCallback(() => {
    const wasm = wasmRef.current;
    if (!wasm) return;
    wasm.clearConsole();
    setState(prev => ({ ...prev, consoleOutput: '' }));
  }, []);

  // Update UI state from WASM
  const updateState = useCallback(() => {
    const wasm = wasmRef.current;
    if (!wasm) return;

    const flags = wasm.getFlags();

    setState(prev => ({
      ...prev,
      registers: Array.from({ length: 8 }, (_, i) => wasm.getRegister(i)),
      pc: wasm.getPC(),
      sp: wasm.getSP(),
      flags: {
        z: (flags & 0x01) !== 0,
        c: (flags & 0x02) !== 0,
        n: (flags & 0x04) !== 0,
        v: (flags & 0x08) !== 0,
      },
      cycles: wasm.getCyclesExecuted(),
      halted: wasm.isHalted(),
    }));

    // Also update console
    updateConsole();
  }, [updateConsole]);

  // Main emulation frame loop
  const frame = useCallback((timestamp: number) => {
    const wasm = wasmRef.current;
    if (!wasm || !state.running) return;
    
    const delta = lastTimestampRef.current ? timestamp - lastTimestampRef.current : 16.67;
    lastTimestampRef.current = timestamp;
    
    // Update timers
    if (delta > 0 && delta < 1000) {
      wasm.updateTimers(Math.floor(delta));
    }
    
    // Calculate cycles to run
    let targetCycles: number;
    if (speedMultiplier === 0) {
      targetCycles = 1000000; // Unlimited
    } else {
      targetCycles = Math.floor(delta * 4000 * speedMultiplier) + cycleDebtRef.current;
    }
    
    // Run emulator
    const cyclesRun = wasm.run(targetCycles);
    cycleDebtRef.current = Math.max(0, targetCycles - cyclesRun);
    cyclesThisSecondRef.current += cyclesRun;

    // Update console output
    updateConsole();

    // Render if DISPLAY was called
    if (wasm.displayRequested()) {
      renderFramebuffer();
      frameCountRef.current++;
    }
    
    // Update FPS counter every second
    if (timestamp - lastFpsUpdateRef.current >= 1000) {
      setState(prev => ({
        ...prev,
        fps: frameCountRef.current,
        mhz: cyclesThisSecondRef.current / 1000000,
        cycles: wasm.getCyclesExecuted(),
      }));
      
      frameCountRef.current = 0;
      cyclesThisSecondRef.current = 0;
      lastFpsUpdateRef.current = timestamp;
    }
    
    // Check for halt
    if (wasm.isHalted()) {
      setState(prev => ({ ...prev, running: false, halted: true }));
      updateState();
      return;
    }
    
    animationFrameRef.current = requestAnimationFrame(frame);
  }, [state.running, speedMultiplier, renderFramebuffer, updateState, updateConsole]);

  // Start emulation
  const start = useCallback(() => {
    if (!state.programLoaded || state.running) return;
    
    lastTimestampRef.current = performance.now();
    lastFpsUpdateRef.current = lastTimestampRef.current;
    frameCountRef.current = 0;
    cyclesThisSecondRef.current = 0;
    cycleDebtRef.current = 0;
    
    setState(prev => ({ ...prev, running: true }));
  }, [state.programLoaded, state.running]);

  // Effect to start animation loop when running changes
  useEffect(() => {
    if (state.running) {
      animationFrameRef.current = requestAnimationFrame(frame);
    }
    return () => {
      if (animationFrameRef.current) {
        cancelAnimationFrame(animationFrameRef.current);
      }
    };
  }, [state.running, frame]);

  // Pause emulation
  const pause = useCallback(() => {
    setState(prev => ({ ...prev, running: false }));
    updateState();
  }, [updateState]);

  // Step one instruction
  const step = useCallback(() => {
    const wasm = wasmRef.current;
    if (!wasm || !state.programLoaded || state.running) return;
    
    wasm.run(1);
    updateState();
    
    if (wasm.displayRequested()) {
      renderFramebuffer();
    }
    
    if (wasm.isHalted()) {
      setState(prev => ({ ...prev, halted: true }));
    }
  }, [state.programLoaded, state.running, updateState, renderFramebuffer]);

  // Load program
  const loadProgram = useCallback((bytes: Uint8Array) => {
    const wasm = wasmRef.current;
    if (!wasm) return;
    
    wasm.init();
    
    const memPtr = wasm.getMemoryPtr();
    const mem = new Uint8Array(wasm.memory.buffer, memPtr, 65536);
    mem.set(bytes.slice(0, Math.min(bytes.length, 16384)));
    
    loadedProgramRef.current = bytes;
    
    // Clear canvas
    const canvas = canvasRef.current;
    if (canvas) {
      const ctx = canvas.getContext('2d');
      if (ctx) {
        ctx.fillStyle = '#000';
        ctx.fillRect(0, 0, 128, 128);
      }
    }
    
    setState({
      ...INITIAL_STATE,
      programLoaded: true,
    });
    
    updateState();
  }, [updateState]);

  // Reset emulator
  const reset = useCallback(() => {
    if (!loadedProgramRef.current) return;
    loadProgram(loadedProgramRef.current);
  }, [loadProgram]);

  // Handle file input
  const loadFile = useCallback(async (file: File) => {
    const buffer = await file.arrayBuffer();
    loadProgram(new Uint8Array(buffer));
  }, [loadProgram]);

  // Keyboard handlers
  const handleKeyDown = useCallback((e: KeyboardEvent) => {
    const wasm = wasmRef.current;
    if (!wasm) return;
    
    const code = KEY_MAP[e.code];
    if (code !== undefined) {
      e.preventDefault();
      wasm.setKeyState(code, 1);
    }
  }, []);

  const handleKeyUp = useCallback(() => {
    const wasm = wasmRef.current;
    if (!wasm) return;
    wasm.setKeyState(0, 0);
  }, []);

  return {
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
  };
}
