import { useState, useEffect, useCallback } from 'react'

type Theme = 'dark' | 'light'

let currentTheme: Theme = 'dark'

export function getTheme(): Theme {
  if (typeof window !== 'undefined') {
    const stored = localStorage.getItem('webhookpulse-theme') as Theme
    if (stored === 'dark' || stored === 'light') return stored
  }
  return currentTheme
}

export function setTheme(theme: Theme) {
  currentTheme = theme
  if (typeof window !== 'undefined') {
    localStorage.setItem('webhookpulse-theme', theme)
    const html = document.documentElement
    if (theme === 'dark') {
      html.classList.add('dark')
      html.classList.remove('light')
    } else {
      html.classList.add('light')
      html.classList.remove('dark')
    }
  }
}

export function useTheme() {
  const [theme, setThemeState] = useState<Theme>(() => getTheme())

  useEffect(() => {
    setTheme(theme)
  }, [theme])

  const toggleTheme = useCallback(() => {
    const next = theme === 'dark' ? 'light' : 'dark'
    setThemeState(next)
    setTheme(next)
  }, [theme])

  return { theme, setTheme: setThemeState, toggleTheme }
}

// Initialize on load
if (typeof window !== 'undefined') {
  const stored = localStorage.getItem('webhookpulse-theme') as Theme
  if (stored === 'dark' || stored === 'light') {
    currentTheme = stored
  }
  setTheme(currentTheme)
}
