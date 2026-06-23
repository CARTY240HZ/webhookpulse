import { useState, useCallback } from 'react'
import { Link } from 'react-router-dom'
import { supabase } from '../lib/supabase'
import { Activity, Loader2, AlertCircle, Mail, ArrowLeft, CheckCircle } from 'lucide-react'

interface FormErrors {
  email?: string
  general?: string
}

export default function ForgotPasswordPage() {
  const [email, setEmail] = useState('')
  const [loading, setLoading] = useState(false)
  const [errors, setErrors] = useState<FormErrors>({})
  const [sent, setSent] = useState(false)

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
    setErrors(newErrors)
    return Object.keys(newErrors).length === 0
  }, [email, validateEmail])

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!validateForm()) return

    setLoading(true)
    setErrors({})

    const { error } = await supabase.auth.resetPasswordForEmail(email.trim(), {
      redirectTo: `${window.location.origin}/reset-password`,
    })

    setLoading(false)

    if (error) {
      setErrors({ general: error.message })
      return
    }

    setSent(true)
  }

  if (sent) {
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
              If an account exists for <strong className="text-text-primary">{email}</strong>, we sent a password reset link.
            </p>
            <Link
              to="/login"
              className="inline-block w-full px-4 py-2.5 rounded text-sm font-medium bg-accent text-background hover:bg-accent-hover transition-colors"
            >
              Back to sign in
            </Link>
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
          <h1 className="text-lg font-semibold text-text-primary mb-1">Reset password</h1>
          <p className="text-sm text-text-secondary mb-6">Enter your email and we will send you a reset link.</p>

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
                />
              </div>
              {errors.email && (
                <p className="mt-1.5 text-xs text-danger flex items-center gap-1">
                  <AlertCircle className="w-3 h-3" />
                  {errors.email}
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
              {loading ? 'Sending...' : 'Send reset link'}
            </button>
          </form>
        </div>

        <div className="text-center mt-6">
          <Link
            to="/login"
            className="inline-flex items-center gap-1.5 text-sm text-text-secondary hover:text-accent transition-colors"
          >
            <ArrowLeft className="w-4 h-4" />
            Back to sign in
          </Link>
        </div>
      </div>
    </div>
  )
}
