import { useRef, useState, useCallback, useEffect } from 'react';

interface AssemblerExports {
  memory: WebAssembly.Memory;
  asm_init: () => void;
  asm_getSourcePtr: () => number;
  asm_setSourceLen: (len: number) => void;
  asm_assemble: () => number;
  asm_getOutputPtr: () => number;
  asm_getOutputLen: () => number;
  asm_getErrorPtr: () => number;
  asm_getErrorLen: () => number;
}

export function useAssembler() {
  const wasmRef = useRef<AssemblerExports | null>(null);
  const [loaded, setLoaded] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    async function loadWasm() {
      try {
        const response = await fetch('/hackvm-asm.wasm');
        const bytes = await response.arrayBuffer();
        const { instance } = await WebAssembly.instantiate(bytes, { env: {} });
        wasmRef.current = instance.exports as unknown as AssemblerExports;
        wasmRef.current.asm_init();
        setLoaded(true);
      } catch (err) {
        console.error('Failed to load assembler WASM:', err);
        setError('Failed to load assembler');
      }
    }
    loadWasm();
  }, []);

  const assemble = useCallback((source: string): { success: boolean; output?: Uint8Array; error?: string } => {
    const wasm = wasmRef.current;
    if (!wasm) {
      return { success: false, error: 'Assembler not loaded' };
    }

    // Re-init for fresh state
    wasm.asm_init();

    // Write source to WASM memory
    const encoder = new TextEncoder();
    const sourceBytes = encoder.encode(source);
    const sourcePtr = wasm.asm_getSourcePtr();
    const sourceMem = new Uint8Array(wasm.memory.buffer, sourcePtr, 65536);
    sourceMem.set(sourceBytes);
    wasm.asm_setSourceLen(sourceBytes.length);

    // Assemble
    const success = wasm.asm_assemble() === 1;

    if (success) {
      const outputPtr = wasm.asm_getOutputPtr();
      const outputLen = wasm.asm_getOutputLen();
      const outputMem = new Uint8Array(wasm.memory.buffer, outputPtr, outputLen);
      // Make a copy since WASM memory might be reused
      const output = new Uint8Array(outputLen);
      output.set(outputMem);
      return { success: true, output };
    } else {
      const errorPtr = wasm.asm_getErrorPtr();
      const errorLen = wasm.asm_getErrorLen();
      const errorMem = new Uint8Array(wasm.memory.buffer, errorPtr, errorLen);
      const decoder = new TextDecoder();
      const errorMsg = decoder.decode(errorMem);
      return { success: false, error: errorMsg };
    }
  }, []);

  return {
    loaded,
    error,
    assemble,
  };
}
