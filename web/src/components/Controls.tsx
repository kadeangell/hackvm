import { useRef } from 'react';
import { Play, Pause, SkipForward, RotateCcw, FolderOpen } from 'lucide-react';
import { Button } from './ui/button';

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
      e.target.value = '';
    }
  };

  return (
    <div className="flex flex-wrap gap-3 mt-5">
      <div className="relative">
        <Button
          variant="secondary"
          onClick={() => fileInputRef.current?.click()}
        >
          <FolderOpen size={18} />
          Load Program
        </Button>
        <input
          ref={fileInputRef}
          type="file"
          accept=".bin,.hvm"
          onChange={handleFileChange}
          className="hidden"
        />
      </div>

      <Button
        variant={running ? 'destructive' : 'secondary'}
        onClick={running ? onPause : onStart}
        disabled={!programLoaded || halted}
      >
        {running ? <Pause size={18} /> : <Play size={18} />}
        {running ? 'Pause' : 'Run'}
      </Button>

      <Button
        variant="secondary"
        onClick={onStep}
        disabled={!programLoaded || running || halted}
      >
        <SkipForward size={18} />
        Step
      </Button>

      <Button
        variant="secondary"
        onClick={onReset}
        disabled={!programLoaded}
      >
        <RotateCcw size={18} />
        Reset
      </Button>
    </div>
  );
}
