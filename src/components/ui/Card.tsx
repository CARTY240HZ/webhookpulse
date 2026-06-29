import { forwardRef, type HTMLAttributes } from 'react'
import { cn } from '../../lib/cn'

interface CardProps extends HTMLAttributes<HTMLDivElement> {
  variant?: 'default' | 'glass' | 'elevated'
  hover?: boolean
}

export const Card = forwardRef<HTMLDivElement, CardProps>(
  ({ className, variant = 'default', hover = false, children, ...props }, ref) => {
    const variants = {
      default: 'bg-card border border-border',
      glass: 'bg-glass backdrop-blur-xl border border-border',
      elevated: 'bg-elevated border border-border',
    }

    return (
      <div
        ref={ref}
        className={cn(
          'rounded-xl transition-all duration-300 ease-smooth',
          variants[variant],
          hover && 'hover:border-border-hover hover:-translate-y-0.5 hover:shadow-lg hover:shadow-accent-glow/10',
          className
        )}
        {...props}
      >
        {children}
      </div>
    )
  }
)
Card.displayName = 'Card'
