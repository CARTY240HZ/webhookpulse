import { useState, useEffect, createContext, useContext, useRef, type ReactNode } from 'react'
import { supabase } from '../lib/supabase'
import type { Profile, AuthState } from '../types'

interface AuthContextValue extends AuthState {
  signOut: () => Promise<void>
  refreshProfile: () => Promise<void>
}

const AuthContext = createContext<AuthContextValue>({
  user: null,
  profile: null,
  loading: true,
  signOut: async () => {},
  refreshProfile: async () => {},
})

export function AuthProvider({ children }: { children: ReactNode }) {
  const [state, setState] = useState<AuthState>({ user: null, profile: null, loading: true })
  const hasFetchedRef = useRef(false)

  useEffect(() => {
    if (hasFetchedRef.current) return
    hasFetchedRef.current = true

    supabase.auth.getSession().then(({ data: { session } }) => {
      const user = session?.user ?? null
      if (user) {
        fetchProfile(user.id)
      } else {
        setState({ user: null, profile: null, loading: false })
      }
    })

    const { data: { subscription } } = supabase.auth.onAuthStateChange((_event, session) => {
      const user = session?.user ?? null
      if (user) {
        fetchProfile(user.id)
      } else {
        setState({ user: null, profile: null, loading: false })
      }
    })

    return () => subscription.unsubscribe()
  }, [])

  async function fetchProfile(userId: string) {
    try {
      const [profileResult, userResult] = await Promise.all([
        supabase.from('profiles').select('*').eq('id', userId).single(),
        supabase.auth.getUser(),
      ])

      const user = userResult.data.user
      setState({
        user: user ? { id: user.id, email: user.email ?? '' } : { id: userId, email: '' },
        profile: profileResult.data ?? null,
        loading: false,
      })
    } catch (err) {
      console.error('fetchProfile error:', err)
      setState({
        user: { id: userId, email: '' },
        profile: null,
        loading: false,
      })
    }
  }

  async function refreshProfile() {
    const userId = state.user?.id
    if (!userId) return
    await fetchProfile(userId)
  }

  async function signOut() {
    await supabase.auth.signOut()
    setState({ user: null, profile: null, loading: false })
  }

  return (
    <AuthContext.Provider value={{ ...state, signOut, refreshProfile }}>
      {children}
    </AuthContext.Provider>
  )
}

export const useAuth = () => useContext(AuthContext)
