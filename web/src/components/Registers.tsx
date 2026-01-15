import { Card, CardHeader, CardTitle, CardContent } from './ui/card';

interface RegistersProps {
  registers: number[];
  pc: number;
  sp: number;
}

function formatHex(value: number): string {
  return value.toString(16).toUpperCase().padStart(4, '0');
}

export function Registers({ registers, pc, sp }: RegistersProps) {
  return (
    <Card>
      <CardHeader className="pb-2">
        <CardTitle className="text-sm uppercase tracking-wider">Registers</CardTitle>
      </CardHeader>
      <CardContent>
        <div className="grid grid-cols-2 gap-2 font-mono text-sm">
          {registers.map((value, i) => (
            <div key={i} className="bg-hvm-input rounded px-2 py-1.5 flex justify-between">
              <span className="text-gray-500">R{i}</span>
              <span className="text-hvm-accent">{formatHex(value)}</span>
            </div>
          ))}
          <div className="bg-hvm-input rounded px-2 py-1.5 flex justify-between">
            <span className="text-gray-500">PC</span>
            <span className="text-hvm-accent">{formatHex(pc)}</span>
          </div>
          <div className="bg-hvm-input rounded px-2 py-1.5 flex justify-between">
            <span className="text-gray-500">SP</span>
            <span className="text-hvm-accent">{formatHex(sp)}</span>
          </div>
        </div>
      </CardContent>
    </Card>
  );
}
