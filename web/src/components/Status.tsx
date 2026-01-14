interface StatusProps {
  running: boolean;
  halted: boolean;
  programLoaded: boolean;
  wasmLoaded: boolean;
}

export function Status({ running, halted, programLoaded, wasmLoaded }: StatusProps) {
  let text: string;
  let colorClass: string;

  if (!wasmLoaded) {
    text = 'Loading emulator...';
    colorClass = 'bg-gray-600';
  } else if (halted) {
    text = 'Halted';
    colorClass = 'bg-hvm-danger';
  } else if (running) {
    text = 'Running';
    colorClass = 'bg-hvm-accent-dim';
  } else if (programLoaded) {
    text = 'Program loaded - Press Run';
    colorClass = 'bg-blue-600';
  } else {
    text = 'Ready - Load a program';
    colorClass = 'bg-blue-600';
  }

  return (
    <div className="bg-hvm-panel rounded-xl p-4 border-2 border-hvm-border">
      <h3 className="text-hvm-accent text-sm font-semibold uppercase tracking-wider mb-3">
        Status
      </h3>
      <div className={`${colorClass} text-center py-2 px-4 rounded-lg font-semibold`}>
        {text}
      </div>
    </div>
  );
}
