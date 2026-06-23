import { useState, useEffect } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { supabase } from '../lib/supabase'
import { Activity, Loader2, AlertCircle, Lock, Eye, EyeOff, CheckCircle } from 'lucide-react'

interface FormErrors {
  password?: string
  confirmPassword?: string
  general?: string
}

export default function ResetPasswordPage() {
  const [password, setPassword] = useState('')
  const [confirmPassword, setConfirmPassword] = useState('')
  const [showPassword, setShowPassword] = useState(false)
  const [showConfirm, setShowConfirm] = useState(false)
  const [loading, setLoading] = useState(false)
  const [errors, setErrors] = useState<FormErrors>({})
  const [success, setSuccess] = useState(false)
  const [hasRecoveryToken, setHasRecoveryToken] = useState(false)
  const navigate = useNavigate()

  useEffect(() => {
    supabase.auth.onAuthStateChange(async (event) => {
      if (event === 'PASSWORD_RECOVERY') {
        setHasRecoveryToken(true)
      }
    })

    const hash = window.location.hash
    if (hash.includes('type=recovery')) {
      setHasRecoveryToken(true)
    }
  }, [])

  const validateForm = (): boolean => {
    const newErrors: FormErrors = {}
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
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!validateForm()) return

    setLoading(true)
    setErrors({})

    const { error } = await supabase.auth.updateUser({ password })

    setLoading(false)

    if (error) {
      setErrors({ general: error.message })
      return
    }

    setSuccess(true)
  }

  if (!hasRecoveryToken) {
    return (
      <div className="min-h-screen bg-background flex items-center justify-center px-4">
        <div className="w-full max-w-sm text-center">
          <div className="flex items-center justify-center gap-2 mb-8">
            <Activity className="w-6 h-6 text-accent" />
            <span className="font-bold text-text-primary text-xl tracking-tight">WebhookPulse</span>
          </div>
          <div className="bg-surface border border-border rounded-lg p-8">
            <AlertCircle className="w-12 h-12 text-text-secondary mx-auto mb-4" />
            <h1 className="text-lg font-semibold text-text-primary mb-2">Invalid or expired link</h1>
            <p className="text-sm text-text-secondary mb-6">
              This password reset link is invalid or has expired. Please request a new one.
            </p>
            <Link
              to="/forgot-password"
              className="inline-block w-full px-4 py-2.5 rounded text-sm font-medium bg-accent text-background hover:bg-accent-hover transition-colors"
            >
              Request new link
            </Link>
          </div>
        </div>
      </div>
    )
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
            <h1 className="text-lg font-semibold text-text-primary mb-2">Password updated</h1>
            <p className="text-sm text-text-secondary mb-6">
              Your password has been reset successfully. You can now sign in with your new password.
            </p>
            <button
              onClick={() => navigate('/login')}
              className="w-full px-4 py-2.5 rounded text-sm font-medium bg-accent text-background hover:bg-accent-hover transition-colors"
            >
              Sign in
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
          <h1 className="text-lg font-semibold text-text-primary mb-1">Set new password</h1>
          <p className="text-sm text-text-secondary mb-6">Create a new password for your account.</p>

          <form onSubmit={handleSubmit} className="space-y-4" noValidate>
            <div>
              <label className="block text-sm font-medium text-text-secondary mb-1.5">New password</label>
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
                  autoFocus
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

            <div>
              <label className="block text-sm font-medium text-text-secondary mb-1.5">Confirm new password</label>
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
              {loading ? 'Updating...' : 'Update password'}
            </button>
          </form>
        </div>
      </div>
    </div>
  )
}
