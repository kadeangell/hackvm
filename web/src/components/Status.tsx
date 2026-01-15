import { Card, CardHeader, CardTitle, CardContent } from './ui/card';
import { Badge } from './ui/badge';

interface StatusProps {
  running: boolean;
  halted: boolean;
  programLoaded: boolean;
  wasmLoaded: boolean;
}

export function Status({ running, halted, programLoaded, wasmLoaded }: StatusProps) {
  let text: string;
  let variant: 'default' | 'secondary' | 'destructive' | 'success';

  if (!wasmLoaded) {
    text = 'Loading emulator...';
    variant = 'secondary';
  } else if (halted) {
    text = 'Halted';
    variant = 'destructive';
  } else if (running) {
    text = 'Running';
    variant = 'success';
  } else if (programLoaded) {
    text = 'Program loaded - Press Run';
    variant = 'default';
  } else {
    text = 'Ready - Load a program';
    variant = 'default';
  }

  return (
    <Card>
      <CardHeader className="pb-2">
        <CardTitle className="text-sm uppercase tracking-wider">Status</CardTitle>
      </CardHeader>
      <CardContent>
        <Badge variant={variant} className="w-full justify-center py-2 text-sm">
          {text}
        </Badge>
      </CardContent>
    </Card>
  );
}
