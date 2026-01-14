import { useRef, useEffect, forwardRef } from 'react';

interface ScreenProps {
  onInit: (canvas: HTMLCanvasElement) => void;
  onKeyDown: (e: KeyboardEvent) => void;
  onKeyUp: (e: KeyboardEvent) => void;
}

export const Screen = forwardRef<HTMLCanvasElement, ScreenProps>(
  ({ onInit, onKeyDown, onKeyUp }, _ref) => {
    const canvasRef = useRef<HTMLCanvasElement>(null);

    useEffect(() => {
      if (canvasRef.current) {
        onInit(canvasRef.current);
      }
    }, [onInit]);

    useEffect(() => {
      const canvas = canvasRef.current;
      if (!canvas) return;

      const handleKeyDown = (e: KeyboardEvent) => onKeyDown(e);
      const handleKeyUp = (e: KeyboardEvent) => onKeyUp(e);
      const handleBlur = () => {
        // Release keys on blur
        onKeyUp(new KeyboardEvent('keyup'));
      };

      canvas.addEventListener('keydown', handleKeyDown);
      canvas.addEventListener('keyup', handleKeyUp);
      canvas.addEventListener('blur', handleBlur);

      return () => {
        canvas.removeEventListener('keydown', handleKeyDown);
        canvas.removeEventListener('keyup', handleKeyUp);
        canvas.removeEventListener('blur', handleBlur);
      };
    }, [onKeyDown, onKeyUp]);

    return (
      <div className="bg-black p-3 rounded-lg inline-block">
        <canvas
          ref={canvasRef}
          width={128}
          height={128}
          tabIndex={0}
          className="block border-2 border-gray-700 focus:border-hvm-accent focus:outline-none cursor-pointer"
          style={{ width: '512px', height: '512px' }}
          onClick={(e) => (e.target as HTMLCanvasElement).focus()}
        />
      </div>
    );
  }
);

Screen.displayName = 'Screen';
