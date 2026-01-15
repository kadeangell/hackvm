import { Card, CardHeader, CardTitle, CardContent } from './ui/card';
import { Tooltip, TooltipContent, TooltipProvider, TooltipTrigger } from './ui/tooltip';

interface FlagsProps {
  flags: {
    z: boolean;
    c: boolean;
    n: boolean;
    v: boolean;
  };
}

export function Flags({ flags }: FlagsProps) {
  const flagItems = [
    { key: 'z', label: 'Z', title: 'Zero', active: flags.z },
    { key: 'c', label: 'C', title: 'Carry', active: flags.c },
    { key: 'n', label: 'N', title: 'Negative', active: flags.n },
    { key: 'v', label: 'V', title: 'Overflow', active: flags.v },
  ];

  return (
    <Card>
      <CardHeader className="pb-2">
        <CardTitle className="text-sm uppercase tracking-wider">Flags</CardTitle>
      </CardHeader>
      <CardContent>
        <TooltipProvider>
          <div className="flex gap-3 justify-center font-mono text-lg">
            {flagItems.map(({ key, label, title, active }) => (
              <Tooltip key={key}>
                <TooltipTrigger asChild>
                  <div
                    className={`w-9 h-9 flex items-center justify-center rounded-lg transition-all cursor-default ${
                      active
                        ? 'bg-hvm-border text-hvm-accent shadow-[0_0_8px_rgba(0,255,136,0.3)]'
                        : 'bg-hvm-input text-gray-600'
                    }`}
                  >
                    {label}
                  </div>
                </TooltipTrigger>
                <TooltipContent>
                  <p>{title}: {active ? 'Set' : 'Clear'}</p>
                </TooltipContent>
              </Tooltip>
            ))}
          </div>
        </TooltipProvider>
      </CardContent>
    </Card>
  );
}
