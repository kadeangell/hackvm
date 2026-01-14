import { useRef } from 'react';
import { Play, Pause, SkipForward, RotateCcw, FolderOpen } from 'lucide-react';

interface ControlsProps {
  running: boolean;
  halted: boolean;
  programLoaded: boolean;
  onStart: () => void;
  onPause: () => void;
  onStep: () => void;
  onReset: () => void;
  onLoadFile: (file: File) => void;
}

export function Controls({
  running,
  halted,
  programLoaded,
  onStart,
  onPause,
  onStep,
  onReset,
  onLoadFile,
}: ControlsProps) {
  const fileInputRef = useRef<HTMLInputElement>(null);

  const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (file) {
      onLoadFile(file);
      e.target.value = ''; // Reset input
    }
  };

  const buttonBase = "flex items-center gap-2 px-4 py-2 rounded-lg font-medium transition-all disabled:opacity-50 disabled:cursor-not-allowed";
  const primaryButton = `${buttonBase} bg-hvm-border hover:bg-hvm-accent-dim text-white`;
  const runningButton = `${buttonBase} bg-hvm-danger text-white`;

  return (
    <div className="flex flex-wrap gap-3 mt-5">
      <div className="relative">
        <button
          className={primaryButton}
          onClick={() => fileInputRef.current?.click()}
        >
          <FolderOpen size={18} />
          Load Program
        </button>
        <input
          ref={fileInputRef}
          type="file"
          accept=".bin,.hvm"
          onChange={handleFileChange}
          className="hidden"
        />
      </div>

      <button
        className={running ? runningButton : primaryButton}
        onClick={running ? onPause : onStart}
        disabled={!programLoaded || halted}
      >
        {running ? <Pause size={18} /> : <Play size={18} />}
        {running ? 'Pause' : 'Run'}
      </button>

      <button
        className={primaryButton}
        onClick={onStep}
        disabled={!programLoaded || running || halted}
      >
        <SkipForward size={18} />
        Step
      </button>

      <button
        className={primaryButton}
        onClick={onReset}
        disabled={!programLoaded}
      >
        <RotateCcw size={18} />
        Reset
      </button>
    </div>
  );
}
