import { useState, useCallback, useRef, useEffect } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { supabase } from '../lib/supabase'
import { Activity, Loader2, Eye, EyeOff, AlertCircle, Mail, Lock } from 'lucide-react'

interface FormErrors {
  email?: string
  password?: string
  general?: string
}

export default function LoginPage() {
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [showPassword, setShowPassword] = useState(false)
  const [loading, setLoading] = useState(false)
  const [errors, setErrors] = useState<FormErrors>({})
  const [attemptCount, setAttemptCount] = useState(0)
  const [isLocked, setIsLocked] = useState(false)
  const [lockTimer, setLockTimer] = useState(0)
  const navigate = useNavigate()
  const intervalRef = useRef<ReturnType<typeof setInterval> | null>(null)

  useEffect(() => {
    return () => {
      if (intervalRef.current) {
        clearInterval(intervalRef.current)
      }
    }
  }, [])

  const validateEmail = useCallback((value: string): boolean => {
    const re = /^[^\s@]+@[^\s@]+\.[^\s@]+$/
    return re.test(value)
  }, [])

  const validateForm = useCallback((): boolean => {
    const newErrors: FormErrors = {}
    if (!email.trim()) {
      newErrors.email = 'Email is required'
    } else if (!validateEmail(email)) {
      newErrors.email = 'Enter a valid email address'
    }
    if (!password) {
      newErrors.password = 'Password is required'
    }
    setErrors(newErrors)
    return Object.keys(newErrors).length === 0
  }, [email, password, validateEmail])

  const startLockout = useCallback(() => {
    setIsLocked(true)
    const duration = 30
    setLockTimer(duration)
    if (intervalRef.current) clearInterval(intervalRef.current)
    intervalRef.current = setInterval(() => {
      setLockTimer((prev) => {
        if (prev <= 1) {
          if (intervalRef.current) clearInterval(intervalRef.current)
          intervalRef.current = null
          setIsLocked(false)
          setAttemptCount(0)
          return 0
        }
        return prev - 1
      })
    }, 1000)
  }, [])

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    if (isLocked) return
    if (!validateForm()) return

    setLoading(true)
    setErrors({})

    const { error: authError } = await supabase.auth.signInWithPassword({ email: email.trim(), password })
    setLoading(false)

    if (authError) {
      const newAttempts = attemptCount + 1
      setAttemptCount(newAttempts)

      if (newAttempts >= 5) {
        setErrors({ general: 'Too many failed attempts. Account locked for 30 seconds.' })
        startLockout()
      } else if (authError.message.includes('Invalid login')) {
        setErrors({ general: 'Invalid email or password.' })
      } else if (authError.message.includes('Email not confirmed')) {
        setErrors({ general: 'Please confirm your email before signing in.' })
      } else {
        setErrors({ general: authError.message })
      }
      return
    }

    setAttemptCount(0)
    navigate('/dashboard')
  }

  return (
    <div className="min-h-screen bg-background flex items-center justify-center px-4">
      <div className="w-full max-w-sm">
        <div className="flex items-center justify-center gap-2 mb-8">
          <Activity className="w-6 h-6 text-accent" />
          <span className="font-bold text-text-primary text-xl tracking-tight">WebhookPulse</span>
        </div>

        <div className="bg-surface border border-border rounded-lg p-6">
          <h1 className="text-lg font-semibold text-text-primary mb-1">Sign in</h1>
          <p className="text-sm text-text-secondary mb-6">Enter your credentials to access your dashboard.</p>

          <form onSubmit={handleSubmit} className="space-y-4" noValidate>
            <div>
              <label className="block text-sm font-medium text-text-secondary mb-1.5">Email</label>
              <div className="relative">
                <Mail className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-text-secondary" />
                <input
                  type="email"
                  value={email}
                  onChange={(e) => { setEmail(e.target.value); setErrors(p => ({ ...p, email: undefined, general: undefined })) }}
                  className={`w-full pl-10 pr-3 py-2.5 bg-background border rounded text-text-primary text-sm transition-colors ${
                    errors.email ? 'border-danger focus:border-danger' : 'border-border focus:border-accent'
                  }`}
                  placeholder="you@example.com"
                  disabled={isLocked}
                />
              </div>
              {errors.email && (
                <p className="mt-1.5 text-xs text-danger flex items-center gap-1">
                  <AlertCircle className="w-3 h-3" />
                  {errors.email}
                </p>
              )}
            </div>

            <div>
              <label className="block text-sm font-medium text-text-secondary mb-1.5">Password</label>
              <div className="relative">
                <Lock className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-text-secondary" />
                <input
                  type={showPassword ? 'text' : 'password'}
                  value={password}
                  onChange={(e) => { setPassword(e.target.value); setErrors(p => ({ ...p, password: undefined, general: undefined })) }}
                  className={`w-full pl-10 pr-10 py-2.5 bg-background border rounded text-text-primary text-sm transition-colors ${
                    errors.password ? 'border-danger focus:border-danger' : 'border-border focus:border-accent'
                  }`}
                  placeholder="••••••••"
                  disabled={isLocked}
                />
                <button
                  type="button"
                  onClick={() => setShowPassword(!showPassword)}
                  className="absolute right-3 top-1/2 -translate-y-1/2 text-text-secondary hover:text-text-primary transition-colors"
                >
                  {showPassword ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
                </button>
              </div>
              {errors.password && (
                <p className="mt-1.5 text-xs text-danger flex items-center gap-1">
                  <AlertCircle className="w-3 h-3" />
                  {errors.password}
                </p>
              )}
            </div>

            {errors.general && (
              <div className="bg-danger/10 border border-danger/20 rounded p-3 text-sm text-danger flex items-start gap-2">
                <AlertCircle className="w-4 h-4 mt-0.5 shrink-0" />
                <span>{errors.general}</span>
              </div>
            )}

            {isLocked && (
              <div className="bg-accent/10 border border-accent/20 rounded p-3 text-sm text-accent">
                Account locked. Try again in {lockTimer}s.
              </div>
            )}

            <button
              type="submit"
              disabled={loading || isLocked}
              className="w-full flex items-center justify-center gap-2 px-4 py-2.5 rounded text-sm font-medium bg-accent text-background hover:bg-accent-hover transition-colors disabled:opacity-50"
            >
              {loading ? <Loader2 className="w-4 h-4 animate-spin" /> : null}
              {loading ? 'Signing in...' : 'Sign in'}
            </button>
          </form>

          <div className="mt-4 text-center">
            <Link
              to="/forgot-password"
              className="text-sm text-text-secondary hover:text-accent transition-colors"
            >
              Forgot your password?
            </Link>
          </div>
        </div>

        <p className="text-center text-sm text-text-secondary mt-6">
          No account?{' '}
          <Link to="/register" className="text-accent hover:text-accent-hover transition-colors font-medium">
            Create one
          </Link>
        </p>
      </div>
    </div>
  )
}
