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
    <div className="bg-hvm-panel rounded-xl p-4 border-2 border-hvm-border">
      <h3 className="text-hvm-accent text-sm font-semibold uppercase tracking-wider mb-3">
        Flags
      </h3>
      <div className="flex gap-3 justify-center font-mono text-lg">
        {flagItems.map(({ key, label, title, active }) => (
          <div
            key={key}
            title={title}
            className={`w-9 h-9 flex items-center justify-center rounded-lg transition-all ${
              active
                ? 'bg-hvm-border text-hvm-accent shadow-[0_0_8px_rgba(0,255,136,0.3)]'
                : 'bg-hvm-input text-gray-600'
            }`}
          >
            {label}
          </div>
        ))}
      </div>
    </div>
  );
}
