import { useState, useEffect } from 'react'

interface ConnectionInfo {
  effectiveType: '2g' | '3g' | '4g' | 'slow-2g' | 'unknown'
  saveData: boolean
  downlink: number
  rtt: number
}

interface NetworkInformation {
  effectiveType?: '2g' | '3g' | '4g' | 'slow-2g' | 'unknown'
  saveData?: boolean
  downlink?: number
  rtt?: number
  addEventListener: (type: string, listener: () => void) => void
  removeEventListener: (type: string, listener: () => void) => void
}

interface NavigatorWithConnection extends Navigator {
  connection?: NetworkInformation
  mozConnection?: NetworkInformation
  webkitConnection?: NetworkInformation
}

export function useAdaptiveServing(): ConnectionInfo {
  const [connection, setConnection] = useState<ConnectionInfo>({
    effectiveType: '4g',
    saveData: false,
    downlink: 10,
    rtt: 50,
  })

  useEffect(() => {
    const nav = navigator as NavigatorWithConnection
    const conn = nav.connection || nav.mozConnection || nav.webkitConnection

    if (!conn) return

    const update = () => {
      setConnection({
        effectiveType: conn.effectiveType || '4g',
        saveData: !!conn.saveData,
        downlink: conn.downlink || 10,
        rtt: conn.rtt || 50,
      })
    }

    update()
    conn.addEventListener('change', update)
    return () => conn.removeEventListener('change', update)
  }, [])

  return connection
}
