import { Card, CardHeader, CardTitle, CardContent } from './ui/card';

interface StatsProps {
  cycles: bigint;
  fps: number;
  mhz: number;
}

export function Stats({ cycles, fps, mhz }: StatsProps) {
  const stats = [
    { label: 'Cycles', value: cycles.toLocaleString() },
    { label: 'FPS', value: fps.toString() },
    { label: 'MHz (actual)', value: mhz.toFixed(2) },
  ];

  return (
    <Card>
      <CardHeader className="pb-2">
        <CardTitle className="text-sm uppercase tracking-wider">Statistics</CardTitle>
      </CardHeader>
      <CardContent>
        <div className="font-mono text-xs space-y-1">
          {stats.map(({ label, value }) => (
            <div
              key={label}
              className="flex justify-between py-1 border-b border-hvm-border last:border-b-0"
            >
              <span className="text-gray-500">{label}</span>
              <span className="text-hvm-accent">{value}</span>
            </div>
          ))}
        </div>
      </CardContent>
    </Card>
  );
}
