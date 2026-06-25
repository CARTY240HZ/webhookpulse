import { useState, useEffect, useRef } from 'react'

interface VirtualListOptions {
  itemHeight: number
  overscan?: number
}

export function useVirtualList<T>(items: T[], options: VirtualListOptions) {
  const { itemHeight, overscan = 5 } = options
  const containerRef = useRef<HTMLDivElement>(null)
  const [scrollTop, setScrollTop] = useState(0)

  const totalHeight = items.length * itemHeight
  const containerHeight = containerRef.current?.clientHeight || 400

  const startIndex = Math.max(0, Math.floor(scrollTop / itemHeight) - overscan)
  const endIndex = Math.min(
    items.length - 1,
    Math.ceil((scrollTop + containerHeight) / itemHeight) + overscan
  )

  const visibleItems = items.slice(startIndex, endIndex + 1)
  const offsetY = startIndex * itemHeight

  useEffect(() => {
    const el = containerRef.current
    if (!el) return

    const handleScroll = () => setScrollTop(el.scrollTop)
    el.addEventListener('scroll', handleScroll, { passive: true })
    return () => el.removeEventListener('scroll', handleScroll)
  }, [])

  return { containerRef, visibleItems, totalHeight, offsetY, startIndex }
}
