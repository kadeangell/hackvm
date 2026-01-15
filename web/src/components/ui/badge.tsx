import * as React from 'react';
import { cn } from './utils';

export interface BadgeProps extends React.HTMLAttributes<HTMLSpanElement> {
  variant?: 'default' | 'secondary' | 'destructive' | 'outline' | 'success';
}

const badgeVariants = {
  default: 'bg-hvm-accent text-hvm-bg',
  secondary: 'bg-hvm-input text-gray-300',
  destructive: 'bg-red-500/20 text-red-400 border-red-500/50',
  outline: 'border border-hvm-border text-gray-300 bg-transparent',
  success: 'bg-green-500/20 text-green-400 border-green-500/50',
};

export const Badge = React.forwardRef<HTMLSpanElement, BadgeProps>(
  ({ className, variant = 'default', ...props }, ref) => {
    return (
      <span
        ref={ref}
        className={cn(
          'inline-flex items-center rounded-md px-2 py-0.5 text-xs font-medium transition-colors',
          badgeVariants[variant],
          className
        )}
        {...props}
      />
    );
  }
);

Badge.displayName = 'Badge';
