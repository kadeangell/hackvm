/**
 * HackVM Emulator - JavaScript Host
 * 
 * Handles WASM loading, display rendering, keyboard input, and timing.
 */

class HackVMEmulator {
    constructor() {
        this.wasm = null;
        this.memory = null;
        this.framebufferOffset = 0;
        this.memoryOffset = 0;
        
        this.canvas = document.getElementById('screen');
        this.ctx = this.canvas.getContext('2d');
        this.imageData = this.ctx.createImageData(128, 128);
        
        // Scale canvas for display
        this.canvas.style.width = '512px';
        this.canvas.style.height = '512px';
        
        this.running = false;
        this.programLoaded = false;
        this.lastTimestamp = 0;
        this.cycleDebt = 0;
        this.speedMultiplier = 1.0;
        
        // Stats tracking
        this.frameCount = 0;
        this.lastFpsUpdate = 0;
        this.cyclesThisSecond = 0;
        this.lastCycleUpdate = 0;
        
        // Program data for reset
        this.loadedProgram = null;
        
        this.setupUI();
        this.setupKeyboard();
        this.loadWasm();
    }
    
    async loadWasm() {
        try {
            const response = await fetch('hackvm.wasm');
            const bytes = await response.arrayBuffer();
            const { instance } = await WebAssembly.instantiate(bytes, {
                env: {}
            });
            
            this.wasm = instance.exports;
            this.wasm.init();
            
            // Get memory views
            this.memory = new Uint8Array(this.wasm.memory.buffer);
            this.framebufferOffset = this.wasm.getFramebufferPtr();
            this.memoryOffset = this.wasm.getMemoryPtr();
            
            this.setStatus('Ready - Load a program', 'ready');
            console.log('HackVM WASM loaded successfully');
        } catch (error) {
            console.error('Failed to load WASM:', error);
            this.setStatus('Error loading emulator', 'halted');
        }
    }
    
    setupUI() {
        // File input
        document.getElementById('fileInput').addEventListener('change', (e) => {
            const file = e.target.files[0];
            if (file) {
                this.loadProgramFile(file);
            }
        });
        
        // Buttons
        document.getElementById('runBtn').addEventListener('click', () => this.start());
        document.getElementById('pauseBtn').addEventListener('click', () => this.pause());
        document.getElementById('stepBtn').addEventListener('click', () => this.step());
        document.getElementById('resetBtn').addEventListener('click', () => this.reset());
        
        // Speed control
        document.getElementById('speedSelect').addEventListener('change', (e) => {
            this.speedMultiplier = parseFloat(e.target.value);
        });
        
        // Canvas focus for keyboard
        this.canvas.tabIndex = 1;
        this.canvas.addEventListener('click', () => this.canvas.focus());
    }
    
    setupKeyboard() {
        // Key mapping
        this.keyMap = {
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
        };
        
        // Add letter keys (A-Z)
        for (let i = 0; i < 26; i++) {
            const letter = String.fromCharCode(65 + i);
            this.keyMap['Key' + letter] = 0x41 + i;
        }
        
        // Add digit keys (0-9)
        for (let i = 0; i < 10; i++) {
            this.keyMap['Digit' + i] = 0x30 + i;
        }
        
        this.canvas.addEventListener('keydown', (e) => {
            const code = this.keyMap[e.code];
            if (code !== undefined && this.wasm) {
                e.preventDefault();
                this.wasm.setKeyState(code, 1);
            }
        });
        
        this.canvas.addEventListener('keyup', (e) => {
            if (this.wasm) {
                this.wasm.setKeyState(0, 0);
            }
        });
        
        // Also handle blur to release keys
        this.canvas.addEventListener('blur', () => {
            if (this.wasm) {
                this.wasm.setKeyState(0, 0);
            }
        });
    }
    
    async loadProgramFile(file) {
        const buffer = await file.arrayBuffer();
        const bytes = new Uint8Array(buffer);
        this.loadProgram(bytes);
    }
    
    loadProgram(bytes) {
        if (!this.wasm) {
            console.error('WASM not loaded');
            return;
        }
        
        this.wasm.init();
        
        // Copy program to WASM memory
        const mem = new Uint8Array(this.wasm.memory.buffer, this.memoryOffset, 65536);
        mem.set(bytes.slice(0, Math.min(bytes.length, 16384)));
        
        // Store for reset
        this.loadedProgram = bytes;
        
        this.programLoaded = true;
        this.running = false;
        this.cycleDebt = 0;
        
        // Clear screen
        this.ctx.fillStyle = '#000';
        this.ctx.fillRect(0, 0, 128, 128);
        
        // Update UI
        this.updateUI();
        this.setStatus('Program loaded - Press Run', 'ready');
        
        document.getElementById('runBtn').disabled = false;
        document.getElementById('stepBtn').disabled = false;
        document.getElementById('resetBtn').disabled = false;
    }
    
    start() {
        if (!this.programLoaded || this.running) return;
        
        this.running = true;
        this.lastTimestamp = performance.now();
        this.lastFpsUpdate = this.lastTimestamp;
        this.lastCycleUpdate = this.lastTimestamp;
        this.frameCount = 0;
        this.cyclesThisSecond = 0;
        
        this.setStatus('Running', 'running');
        document.getElementById('runBtn').disabled = true;
        document.getElementById('runBtn').classList.add('running');
        document.getElementById('pauseBtn').disabled = false;
        
        this.canvas.focus();
        requestAnimationFrame((t) => this.frame(t));
    }
    
    pause() {
        this.running = false;
        this.setStatus('Paused', 'ready');
        document.getElementById('runBtn').disabled = false;
        document.getElementById('runBtn').classList.remove('running');
        document.getElementById('pauseBtn').disabled = true;
        this.updateUI();
    }
    
    step() {
        if (!this.programLoaded || this.running) return;
        
        // Run one instruction
        const cycles = this.wasm.run(1);
        this.updateUI();
        
        if (this.wasm.displayRequested()) {
            this.renderFramebuffer();
        }
        
        if (this.wasm.isHalted()) {
            this.setStatus('Halted', 'halted');
            document.getElementById('runBtn').disabled = true;
            document.getElementById('stepBtn').disabled = true;
        }
    }
    
    reset() {
        if (!this.loadedProgram) return;
        
        this.running = false;
        this.loadProgram(this.loadedProgram);
        
        document.getElementById('runBtn').disabled = false;
        document.getElementById('runBtn').classList.remove('running');
        document.getElementById('pauseBtn').disabled = true;
        document.getElementById('stepBtn').disabled = false;
    }
    
    frame(timestamp) {
        if (!this.running) return;
        
        // Calculate delta time
        const delta = timestamp - this.lastTimestamp;
        this.lastTimestamp = timestamp;
        
        // Update timers based on wall clock
        if (delta > 0 && delta < 1000) {
            this.wasm.updateTimers(Math.floor(delta));
        }
        
        // Calculate cycles to run (4 MHz = 4000 cycles/ms)
        let targetCycles;
        if (this.speedMultiplier === 0) {
            // Unlimited - run as many as possible
            targetCycles = 1000000;
        } else {
            targetCycles = Math.floor(delta * 4000 * this.speedMultiplier) + this.cycleDebt;
        }
        
        // Run emulator
        const cyclesRun = this.wasm.run(targetCycles);
        this.cycleDebt = Math.max(0, targetCycles - cyclesRun);
        this.cyclesThisSecond += cyclesRun;
        
        // Render if DISPLAY was called
        if (this.wasm.displayRequested()) {
            this.renderFramebuffer();
            this.frameCount++;
        }
        
        // Update FPS counter every second
        if (timestamp - this.lastFpsUpdate >= 1000) {
            document.getElementById('fps').textContent = this.frameCount;
            document.getElementById('mhz').textContent = (this.cyclesThisSecond / 1000000).toFixed(2);
            
            this.frameCount = 0;
            this.cyclesThisSecond = 0;
            this.lastFpsUpdate = timestamp;
        }
        
        // Update cycle counter
        document.getElementById('cycles').textContent = this.wasm.getCyclesExecuted().toLocaleString();
        
        // Check for halt
        if (this.wasm.isHalted()) {
            this.running = false;
            this.setStatus('Halted', 'halted');
            document.getElementById('runBtn').disabled = true;
            document.getElementById('runBtn').classList.remove('running');
            document.getElementById('pauseBtn').disabled = true;
            document.getElementById('stepBtn').disabled = true;
            this.updateUI();
            return;
        }
        
        // Schedule next frame
        requestAnimationFrame((t) => this.frame(t));
    }
    
    renderFramebuffer() {
        // Get framebuffer from WASM memory
        const fb = new Uint8Array(this.wasm.memory.buffer, this.framebufferOffset, 16384);
        const pixels = this.imageData.data;
        
        // Convert RGB332 to RGBA
        for (let i = 0; i < 16384; i++) {
            const rgb332 = fb[i];
            
            // Extract components
            const r3 = (rgb332 >> 5) & 0x07;
            const g3 = (rgb332 >> 2) & 0x07;
            const b2 = rgb332 & 0x03;
            
            // Scale to 8-bit
            // 3-bit: 0-7 -> 0-255 (multiply by 36.43, or use lookup)
            // 2-bit: 0-3 -> 0-255 (multiply by 85)
            const r = Math.round(r3 * 255 / 7);
            const g = Math.round(g3 * 255 / 7);
            const b = Math.round(b2 * 255 / 3);
            
            const idx = i * 4;
            pixels[idx] = r;
            pixels[idx + 1] = g;
            pixels[idx + 2] = b;
            pixels[idx + 3] = 255;
        }
        
        this.ctx.putImageData(this.imageData, 0, 0);
    }
    
    updateUI() {
        if (!this.wasm) return;
        
        // Update registers
        for (let i = 0; i < 8; i++) {
            const val = this.wasm.getRegister(i);
            document.getElementById('r' + i).textContent = val.toString(16).toUpperCase().padStart(4, '0');
        }
        
        document.getElementById('pc').textContent = this.wasm.getPC().toString(16).toUpperCase().padStart(4, '0');
        document.getElementById('sp').textContent = this.wasm.getSP().toString(16).toUpperCase().padStart(4, '0');
        
        // Update flags
        const flags = this.wasm.getFlags();
        document.getElementById('flag-z').classList.toggle('active', (flags & 0x01) !== 0);
        document.getElementById('flag-c').classList.toggle('active', (flags & 0x02) !== 0);
        document.getElementById('flag-n').classList.toggle('active', (flags & 0x04) !== 0);
        document.getElementById('flag-v').classList.toggle('active', (flags & 0x08) !== 0);
        
        // Update cycles
        document.getElementById('cycles').textContent = this.wasm.getCyclesExecuted().toLocaleString();
    }
    
    setStatus(text, className) {
        const status = document.getElementById('status');
        status.textContent = text;
        status.className = 'status ' + className;
    }
}

// Initialize emulator when page loads
window.addEventListener('DOMContentLoaded', () => {
    window.emulator = new HackVMEmulator();
});
