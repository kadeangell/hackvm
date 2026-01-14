import { SPEED_OPTIONS } from '../types';

interface SpeedControlProps {
  value: number;
  onChange: (value: number) => void;
}

export function SpeedControl({ value, onChange }: SpeedControlProps) {
  return (
    <div className="flex items-center gap-3 mt-4">
      <label className="text-sm text-gray-400">Speed:</label>
      <select
        value={value}
        onChange={(e) => onChange(parseFloat(e.target.value))}
        className="bg-hvm-input text-white border border-hvm-border rounded px-3 py-1.5 focus:border-hvm-accent focus:outline-none"
      >
        {SPEED_OPTIONS.map((opt) => (
          <option key={opt.value} value={opt.value}>
            {opt.label}
          </option>
        ))}
      </select>
    </div>
  );
}
