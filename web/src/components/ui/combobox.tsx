import * as React from 'react';
import { Check, ChevronsUpDown } from 'lucide-react';
import { Popover, PopoverContent, PopoverTrigger } from './popover';
import { Button } from './button';
import { cn } from './utils';

export interface ComboboxOption {
  value: string;
  label: string;
}

export interface ComboboxProps {
  options: ComboboxOption[];
  value?: string;
  onValueChange?: (value: string) => void;
  placeholder?: string;
  searchPlaceholder?: string;
  emptyText?: string;
  className?: string;
}

export function Combobox({
  options,
  value,
  onValueChange,
  placeholder = 'Select option...',
  searchPlaceholder = 'Search...',
  emptyText = 'No results found.',
  className,
}: ComboboxProps) {
  const [open, setOpen] = React.useState(false);
  const [search, setSearch] = React.useState('');

  const filteredOptions = React.useMemo(() => {
    if (!search) return options;
    const lower = search.toLowerCase();
    return options.filter(
      (option) =>
        option.label.toLowerCase().includes(lower) ||
        option.value.toLowerCase().includes(lower)
    );
  }, [options, search]);

  const selectedOption = options.find((option) => option.value === value);

  return (
    <Popover open={open} onOpenChange={setOpen}>
      <PopoverTrigger asChild>
        <Button
          variant="outline"
          role="combobox"
          aria-expanded={open}
          className={cn('w-[200px] justify-between', className)}
        >
          {selectedOption ? selectedOption.label : placeholder}
          <ChevronsUpDown className="ml-2 h-4 w-4 shrink-0 opacity-50" />
        </Button>
      </PopoverTrigger>
      <PopoverContent className="w-[200px] p-0">
        <div className="p-2">
          <input
            type="text"
            placeholder={searchPlaceholder}
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            className="w-full rounded-md border border-hvm-border bg-hvm-input px-3 py-2 text-sm text-gray-300 placeholder:text-gray-500 focus:outline-none focus:ring-1 focus:ring-hvm-accent"
          />
        </div>
        <div className="max-h-[200px] overflow-y-auto">
          {filteredOptions.length === 0 ? (
            <p className="p-2 text-center text-sm text-gray-500">{emptyText}</p>
          ) : (
            <ul className="p-1">
              {filteredOptions.map((option) => (
                <li key={option.value}>
                  <button
                    type="button"
                    onClick={() => {
                      onValueChange?.(option.value === value ? '' : option.value);
                      setOpen(false);
                      setSearch('');
                    }}
                    className={cn(
                      'flex w-full items-center rounded-sm px-2 py-1.5 text-sm outline-none',
                      'hover:bg-hvm-input focus:bg-hvm-input',
                      value === option.value && 'bg-hvm-input'
                    )}
                  >
                    <Check
                      className={cn(
                        'mr-2 h-4 w-4',
                        value === option.value ? 'opacity-100' : 'opacity-0'
                      )}
                    />
                    {option.label}
                  </button>
                </li>
              ))}
            </ul>
          )}
        </div>
      </PopoverContent>
    </Popover>
  );
}
