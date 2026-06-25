import { useState, useEffect } from 'react'
import { Search, ChevronDown, ChevronUp, X } from 'lucide-react'
import { t } from '../i18n'
import { useDebounce } from '../hooks/useDebounce'
import type { LogFilters } from '../hooks/useRealtimeLogs'

interface SearchBarProps {
  filters: LogFilters
  onChange: (filters: LogFilters) => void
  sources: string[]
}

export default function SearchBar({ filters, onChange, sources }: SearchBarProps) {
  const [expanded, setExpanded] = useState(false)
  const [draft, setDraft] = useState<LogFilters>(filters)
  const [searchInput, setSearchInput] = useState(filters.q || '')
  const debouncedSearch = useDebounce(searchInput, 300)

  useEffect(() => {
    setDraft(filters)
    setSearchInput(filters.q || '')
  }, [filters])

  // Sync debounced search input into draft.q
  useEffect(() => {
    const currentQ = draft.q || ''
    if (debouncedSearch !== currentQ) {
      setDraft((prev) => ({ ...prev, q: debouncedSearch || undefined }))
    }
  }, [debouncedSearch, draft.q])

  const updateDraft = (key: keyof LogFilters, value: string | undefined) => {
    setDraft((prev) => ({ ...prev, [key]: value || undefined }))
  }

  const handleApply = () => {
    onChange(draft)
  }

  const handleClear = () => {
    const empty: LogFilters = {}
    setDraft(empty)
    onChange(empty)
  }

  const activeCount = [
    filters.q,
    filters.ip,
    filters.from,
    filters.to,
    filters.source,
    filters.type && filters.type !== 'all',
  ].filter(Boolean).length

  return (
    <div className="bg-surface border border-border rounded">
      {/* Collapsible header */}
      <button
        onClick={() => setExpanded(!expanded)}
        className="w-full flex items-center justify-between px-4 py-3 text-left hover:bg-elevated/30 transition-colors"
      >
        <div className="flex items-center gap-2">
          <Search className="w-4 h-4 text-accent" />
          <span className="text-sm font-medium text-text-primary">
            {t('search.title')}
          </span>
          {activeCount > 0 && (
            <span className="ml-2 inline-flex items-center justify-center w-5 h-5 rounded-full text-[10px] font-bold bg-accent text-background">
              {activeCount}
            </span>
          )}
        </div>
        <div className="flex items-center gap-2">
          {activeCount > 0 && (
            <button
              onClick={(e) => {
                e.stopPropagation()
                handleClear()
              }}
              className="flex items-center gap-1 text-xs text-text-secondary hover:text-danger transition-colors"
            >
              <X className="w-3 h-3" />
              {t('search.clear')}
            </button>
          )}
          {expanded ? (
            <ChevronUp className="w-4 h-4 text-text-secondary" />
          ) : (
            <ChevronDown className="w-4 h-4 text-text-secondary" />
          )}
        </div>
      </button>

      {/* Expanded panel */}
      {expanded && (
        <div className="px-4 pb-4 border-t border-border space-y-4">
          {/* Search input */}
          <div className="pt-3">
            <label className="block text-xs font-medium text-text-secondary mb-1.5">
              {t('search.placeholder')}
            </label>
            <input
              type="text"
              value={searchInput}
              onChange={(e) => setSearchInput(e.target.value)}
              placeholder={t('search.placeholder')}
              className="w-full px-3 py-2 bg-background border border-border rounded text-sm text-text-primary placeholder-text-secondary focus:border-accent focus:outline-none transition-colors"
            />
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            {/* IP filter */}
            <div>
              <label className="block text-xs font-medium text-text-secondary mb-1.5">
                {t('search.ip')}
              </label>
              <input
                type="text"
                value={draft.ip || ''}
                onChange={(e) => updateDraft('ip', e.target.value)}
                placeholder="192.168.1.1"
                className="w-full px-3 py-2 bg-background border border-border rounded text-sm text-text-primary placeholder-text-secondary focus:border-accent focus:outline-none transition-colors"
              />
            </div>

            {/* Source filter */}
            <div>
              <label className="block text-xs font-medium text-text-secondary mb-1.5">
                {t('search.source')}
              </label>
              <select
                value={draft.source || ''}
                onChange={(e) => updateDraft('source', e.target.value || undefined)}
                className="w-full px-3 py-2 bg-background border border-border rounded text-sm text-text-primary focus:border-accent focus:outline-none transition-colors appearance-none cursor-pointer"
              >
                <option value="">{t('search.all')}</option>
                {sources.map((s) => (
                  <option key={s} value={s}>
                    {s}
                  </option>
                ))}
              </select>
            </div>

            {/* Date range */}
            <div>
              <label className="block text-xs font-medium text-text-secondary mb-1.5">
                {t('search.from')}
              </label>
              <input
                type="date"
                value={draft.from || ''}
                onChange={(e) => updateDraft('from', e.target.value || undefined)}
                className="w-full px-3 py-2 bg-background border border-border rounded text-sm text-text-primary focus:border-accent focus:outline-none transition-colors [color-scheme:dark]"
              />
            </div>
            <div>
              <label className="block text-xs font-medium text-text-secondary mb-1.5">
                {t('search.to')}
              </label>
              <input
                type="date"
                value={draft.to || ''}
                onChange={(e) => updateDraft('to', e.target.value || undefined)}
                className="w-full px-3 py-2 bg-background border border-border rounded text-sm text-text-primary focus:border-accent focus:outline-none transition-colors [color-scheme:dark]"
              />
            </div>
          </div>

          {/* Type filter */}
          <div>
            <label className="block text-xs font-medium text-text-secondary mb-1.5">
              {t('search.type')}
            </label>
            <div className="flex items-center gap-2">
              {(['all', 'native', 'discord'] as const).map((type) => {
                const isActive =
                  draft.type === type || (type === 'all' && !draft.type)
                return (
                  <button
                    key={type}
                    onClick={() => updateDraft('type', type)}
                    className={`px-3 py-1.5 rounded text-xs font-medium transition-colors ${
                      isActive
                        ? 'bg-accent text-background'
                        : 'bg-background border border-border text-text-primary hover:bg-elevated'
                    }`}
                  >
                    {type === 'all'
                      ? t('search.all')
                      : type === 'native'
                        ? t('webhooks.native')
                        : t('webhooks.discord')}
                  </button>
                )
              })}
            </div>
          </div>

          {/* Apply button */}
          <div className="flex justify-end pt-1">
            <button
              onClick={handleApply}
              className="px-5 py-2 rounded text-sm font-medium bg-accent text-background hover:bg-accent-hover transition-colors"
            >
              {t('search.apply')}
            </button>
          </div>
        </div>
      )}
    </div>
  )
}
