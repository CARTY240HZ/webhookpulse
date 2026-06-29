import { useState, useCallback } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { supabase } from '../lib/supabase'
import { Activity, Loader2, Eye, EyeOff, AlertCircle, Mail, Lock, User, CheckCircle } from 'lucide-react'

interface FormErrors {
  fullName?: string
  email?: string
  password?: string
  confirmPassword?: string
  general?: string
}

interface PasswordStrength {
  score: number
  label: string
  color: string
}

function getPasswordStrength(password: string): PasswordStrength {
  let score = 0
  if (password.length >= 8) score++
  if (/[A-Z]/.test(password)) score++
  if (/[0-9]/.test(password)) score++
  if (/[^A-Za-z0-9]/.test(password)) score++

  const map: Record<number, { label: string; color: string }> = {
    0: { label: 'Too weak', color: 'bg-danger' },
    1: { label: 'Weak', color: 'bg-danger' },
    2: { label: 'Fair', color: 'bg-warning' },
    3: { label: 'Good', color: 'bg-success' },
    4: { label: 'Strong', color: 'bg-success' },
  }
  return { score, ...map[score] }
}

export default function RegisterPage() {
  const [fullName, setFullName] = useState('')
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [confirmPassword, setConfirmPassword] = useState('')
  const [showPassword, setShowPassword] = useState(false)
  const [showConfirm, setShowConfirm] = useState(false)
  const [loading, setLoading] = useState(false)
  const [errors, setErrors] = useState<FormErrors>({})
  const [success, setSuccess] = useState(false)
  const navigate = useNavigate()

  const strength = getPasswordStrength(password)

  const validateEmail = useCallback((value: string): boolean => {
    const re = /^[^\s@]+@[^\s@]+\.[^\s@]+$/
    return re.test(value)
  }, [])

  const validateForm = useCallback((): boolean => {
    const newErrors: FormErrors = {}
    if (!fullName.trim()) {
      newErrors.fullName = 'Full name is required'
    }
    if (!email.trim()) {
      newErrors.email = 'Email is required'
    } else if (!validateEmail(email)) {
      newErrors.email = 'Enter a valid email address'
    }
    if (!password) {
      newErrors.password = 'Password is required'
    } else if (password.length < 6) {
      newErrors.password = 'Password must be at least 6 characters'
    }
    if (password !== confirmPassword) {
      newErrors.confirmPassword = 'Passwords do not match'
    }
    setErrors(newErrors)
    return Object.keys(newErrors).length === 0
  }, [fullName, email, password, confirmPassword, validateEmail])

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!validateForm()) return

    setLoading(true)
    setErrors({})

    const { error: authError } = await supabase.auth.signUp({
      email: email.trim(),
      password,
      options: {
        data: { full_name: fullName.trim() },
        emailRedirectTo: `${window.location.origin}/login`,
      },
    })

    setLoading(false)

    if (authError) {
      if (authError.message.includes('already registered')) {
        setErrors({ general: 'An account with this email already exists.' })
      } else {
        setErrors({ general: authError.message })
      }
      return
    }

    setSuccess(true)
  }

  if (success) {
    return (
      <div className="min-h-screen bg-background flex items-center justify-center px-4">
        <div className="w-full max-w-sm text-center">
          <div className="flex items-center justify-center gap-2 mb-8">
            <Activity className="w-6 h-6 text-accent" />
            <span className="font-bold text-text-primary text-xl tracking-tight">WebhookPulse</span>
          </div>
          <div className="bg-surface border border-border rounded-lg p-8">
            <CheckCircle className="w-12 h-12 text-success mx-auto mb-4" />
            <h1 className="text-lg font-semibold text-text-primary mb-2">Check your email</h1>
            <p className="text-sm text-text-secondary mb-6">
              We sent a confirmation link to <strong className="text-text-primary">{email}</strong>.
              Click it to activate your account.
            </p>
            <button
              onClick={() => navigate('/login')}
              className="w-full px-4 py-2.5 rounded text-sm font-medium bg-accent text-background hover:bg-accent-hover transition-colors"
            >
              Go to sign in
            </button>
          </div>
        </div>
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-background flex items-center justify-center px-4">
      <div className="w-full max-w-sm">
        <div className="flex items-center justify-center gap-2 mb-8">
          <Activity className="w-6 h-6 text-accent" />
          <span className="font-bold text-text-primary text-xl tracking-tight">WebhookPulse</span>
        </div>

        <div className="bg-surface border border-border rounded-lg p-6">
          <h1 className="text-lg font-semibold text-text-primary mb-1">Create account</h1>
          <p className="text-sm text-text-secondary mb-6">Set up your WebhookPulse account in seconds.</p>

          <form onSubmit={handleSubmit} className="space-y-4" noValidate>
            <div>
              <label className="block text-sm font-medium text-text-secondary mb-1.5">Full name</label>
              <div className="relative">
                <User className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-text-secondary" />
                <input
                  type="text"
                  value={fullName}
                  onChange={(e) => { setFullName(e.target.value); setErrors(p => ({ ...p, fullName: undefined, general: undefined })) }}
                  className={`w-full pl-10 pr-3 py-2.5 bg-background border rounded text-text-primary text-sm transition-colors ${
                    errors.fullName ? 'border-danger focus:border-danger' : 'border-border focus:border-accent'
                  }`}
                  placeholder="John Doe"
                />
              </div>
              {errors.fullName && (
                <p className="mt-1.5 text-xs text-danger flex items-center gap-1">
                  <AlertCircle className="w-3 h-3" />
                  {errors.fullName}
                </p>
              )}
            </div>

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
                />
                <button
                  type="button"
                  onClick={() => setShowPassword(!showPassword)}
                  className="absolute right-3 top-1/2 -translate-y-1/2 text-text-secondary hover:text-text-primary transition-colors"
                >
                  {showPassword ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
                </button>
              </div>
              {password && (
                <div className="mt-2">
                  <div className="flex gap-1 mb-1">
                    {[1, 2, 3, 4].map((i) => (
                      <div
                        key={i}
                        className={`h-1.5 flex-1 rounded-full transition-colors ${
                          i <= strength.score ? strength.color : 'bg-border'
                        }`}
                      />
                    ))}
                  </div>
                  <p className="text-xs text-text-secondary">{strength.label}</p>
                </div>
              )}
              {errors.password && (
                <p className="mt-1.5 text-xs text-danger flex items-center gap-1">
                  <AlertCircle className="w-3 h-3" />
                  {errors.password}
                </p>
              )}
            </div>

            <div>
              <label className="block text-sm font-medium text-text-secondary mb-1.5">Confirm password</label>
              <div className="relative">
                <Lock className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-text-secondary" />
                <input
                  type={showConfirm ? 'text' : 'password'}
                  value={confirmPassword}
                  onChange={(e) => { setConfirmPassword(e.target.value); setErrors(p => ({ ...p, confirmPassword: undefined, general: undefined })) }}
                  className={`w-full pl-10 pr-10 py-2.5 bg-background border rounded text-text-primary text-sm transition-colors ${
                    errors.confirmPassword ? 'border-danger focus:border-danger' : 'border-border focus:border-accent'
                  }`}
                  placeholder="••••••••"
                />
                <button
                  type="button"
                  onClick={() => setShowConfirm(!showConfirm)}
                  className="absolute right-3 top-1/2 -translate-y-1/2 text-text-secondary hover:text-text-primary transition-colors"
                >
                  {showConfirm ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
                </button>
              </div>
              {errors.confirmPassword && (
                <p className="mt-1.5 text-xs text-danger flex items-center gap-1">
                  <AlertCircle className="w-3 h-3" />
                  {errors.confirmPassword}
                </p>
              )}
            </div>

            {errors.general && (
              <div className="bg-danger/10 border border-danger/20 rounded p-3 text-sm text-danger flex items-start gap-2">
                <AlertCircle className="w-4 h-4 mt-0.5 shrink-0" />
                <span>{errors.general}</span>
              </div>
            )}

            <button
              type="submit"
              disabled={loading}
              className="w-full flex items-center justify-center gap-2 px-4 py-2.5 rounded text-sm font-medium bg-accent text-background hover:bg-accent-hover transition-colors disabled:opacity-50"
            >
              {loading ? <Loader2 className="w-4 h-4 animate-spin" /> : null}
              {loading ? 'Creating...' : 'Create account'}
            </button>
          </form>
        </div>

        <p className="text-center text-sm text-text-secondary mt-6">
          Already have an account?{' '}
          <Link to="/login" className="text-accent hover:text-accent-hover transition-colors font-medium">
            Sign in
          </Link>
        </p>
      </div>
    </div>
  )
}
