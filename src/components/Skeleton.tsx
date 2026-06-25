import React from 'react'

export const SkeletonCard = React.memo(function SkeletonCard() {
  return (
    <div className="animate-pulse bg-surface border border-border rounded p-4 space-y-3">
      <div className="flex items-center gap-3">
        <div className="w-3 h-3 rounded-full bg-border" />
        <div className="h-4 bg-border rounded w-1/3" />
      </div>
      <div className="h-3 bg-border rounded w-2/3" />
      <div className="flex gap-2">
        <div className="h-3 bg-border rounded w-16" />
        <div className="h-3 bg-border rounded w-12" />
      </div>
    </div>
  )
})

export const SkeletonChart = React.memo(function SkeletonChart() {
  return (
    <div className="animate-pulse bg-surface border border-border rounded p-4">
      <div className="h-4 bg-border rounded w-1/4 mb-4" />
      <div className="flex items-end gap-1 h-32">
        {Array.from({ length: 24 }).map((_, i) => (
          <div
            key={i}
            className="flex-1 bg-border rounded-t"
            style={{ height: `${20 + Math.random() * 60}%` }}
          />
        ))}
      </div>
    </div>
  )
})

export const SkeletonRow = React.memo(function SkeletonRow() {
  return (
    <div className="animate-pulse flex items-center gap-3 px-4 py-3 border-b border-border">
      <div className="w-2 h-2 rounded-full bg-border" />
      <div className="flex-1 space-y-1">
        <div className="h-3 bg-border rounded w-1/4" />
        <div className="h-2 bg-border rounded w-1/3" />
      </div>
      <div className="h-3 bg-border rounded w-12" />
    </div>
  )
})
