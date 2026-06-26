import { useState, useEffect, useRef, useMemo, useCallback } from 'react'

interface VirtualListOptions {
  itemHeight: number
  overscan?: number
}

export function useVirtualList<T>(items: T[], options: VirtualListOptions) {
  const { itemHeight, overscan = 5 } = options
  const containerRef = useRef<HTMLDivElement>(null)
  const [scrollTop, setScrollTop] = useState(0)
  const [containerHeight, setContainerHeight] = useState(400)

  useEffect(() => {
    const el = containerRef.current
    if (!el) return

    const resizeObserver = new ResizeObserver((entries) => {
      for (const entry of entries) {
        setContainerHeight(entry.contentRect.height)
      }
    })
    resizeObserver.observe(el)

    // Initial measurement
    setContainerHeight(el.clientHeight)

    const handleScroll = () => setScrollTop(el.scrollTop)
    el.addEventListener('scroll', handleScroll, { passive: true })

    return () => {
      el.removeEventListener('scroll', handleScroll)
      resizeObserver.disconnect()
    }
  }, [])

  const totalHeight = items.length * itemHeight

  const { visibleItems, offsetY, startIndex } = useMemo(() => {
    const startIndex = Math.max(0, Math.floor(scrollTop / itemHeight) - overscan)
    const endIndex = Math.min(
      items.length - 1,
      Math.ceil((scrollTop + containerHeight) / itemHeight) + overscan
    )
    const visibleItems = items.slice(startIndex, endIndex + 1)
    const offsetY = startIndex * itemHeight
    return { visibleItems, offsetY, startIndex }
  }, [items, scrollTop, containerHeight, itemHeight, overscan])

  return { containerRef, visibleItems, totalHeight, offsetY, startIndex }
}
