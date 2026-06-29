import { forwardRef, type HTMLAttributes } from 'react'
import { cn } from '../lib/cn'

interface BadgeProps extends HTMLAttributes<HTMLSpanElement> {
  variant?: 'accent' | 'success' | 'danger' | 'warning' | 'info' | 'ghost'
}

export const Badge = forwardRef<HTMLSpanElement, BadgeProps>(
  ({ className, variant = 'accent', children, ...props }, ref) => {
    const variants = {
      accent: 'bg-accent/10 text-accent border border-accent/20',
      success: 'bg-success/10 text-success border border-success/20',
      danger: 'bg-danger/10 text-danger border border-danger/20',
      warning: 'bg-warning/10 text-warning border border-warning/20',
      info: 'bg-info/10 text-info border border-info/20',
      ghost: 'bg-transparent text-text-secondary border border-border',
    }

    return (
      <span
        ref={ref}
        className={cn(
          'inline-flex items-center gap-1 px-2.5 py-0.5 rounded-full text-xs font-medium',
          variants[variant],
          className
        )}
        {...props}
      >
        {children}
      </span>
    )
  }
)
Badge.displayName = 'Badge'
