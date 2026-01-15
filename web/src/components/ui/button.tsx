import * as React from 'react';
import { cn } from './utils';

export interface ButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: 'default' | 'secondary' | 'destructive' | 'outline' | 'ghost' | 'link';
  size?: 'default' | 'sm' | 'lg' | 'icon';
}

const buttonVariants = {
  default: 'bg-hvm-accent text-hvm-bg hover:bg-hvm-accent/90',
  secondary: 'bg-hvm-input text-gray-300 hover:bg-hvm-input/80',
  destructive: 'bg-red-500 text-white hover:bg-red-500/90',
  outline: 'border border-hvm-border bg-transparent hover:bg-hvm-input text-gray-300',
  ghost: 'hover:bg-hvm-input text-gray-300',
  link: 'text-hvm-accent underline-offset-4 hover:underline',
};

const buttonSizes = {
  default: 'h-9 px-4 py-2',
  sm: 'h-8 rounded-md px-3 text-xs',
  lg: 'h-10 rounded-md px-8',
  icon: 'h-9 w-9',
};

export const Button = React.forwardRef<HTMLButtonElement, ButtonProps>(
  ({ className, variant = 'default', size = 'default', ...props }, ref) => {
    return (
      <button
        ref={ref}
        className={cn(
          'inline-flex items-center justify-center gap-2 whitespace-nowrap rounded-md text-sm font-medium',
          'transition-colors focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-hvm-accent',
          'disabled:pointer-events-none disabled:opacity-50',
          buttonVariants[variant],
          buttonSizes[size],
          className
        )}
        {...props}
      />
    );
  }
);

Button.displayName = 'Button';
