import { useState, useEffect, useCallback } from 'react'
import { useNavigate } from 'react-router-dom'
import { useAuth } from '../hooks/useAuth'
import { supabase } from '../lib/supabase'
import type { AccountSettings } from '../types'
import {
  User, Phone, MapPin, Globe, Mail, Lock, Trash2, Save,
  Loader2, AlertTriangle, Eye, EyeOff, Moon, Sun, Bell,
  Languages, ChevronDown, Shield, LogOut
} from 'lucide-react'

const API_BASE = import.meta.env.VITE_API_URL || ''

type ToastType = 'success' | 'error' | 'info'

interface Toast {
  id: string
  message: string
  type: ToastType
}

const LANGUAGES = [
  { code: 'en', label: 'English' },
  { code: 'es', label: 'Español' },
]

const THEMES = [
  { code: 'dark', label: 'Dark', icon: Moon },
  { code: 'light', label: 'Light', icon: Sun },
]

export default function SettingsPage() {
  const { user, signOut } = useAuth()
  const navigate = useNavigate()

  // ── Profile ──
  const [settings, setSettings] = useState<AccountSettings | null>(null)
  const [loading, setLoading] = useState(true)
  const [savingProfile, setSavingProfile] = useState(false)

  // ── Password ──
  const [currentPassword, setCurrentPassword] = useState('')
  const [newPassword, setNewPassword] = useState('')
  const [confirmPassword, setConfirmPassword] = useState('')
  const [showCurr, setShowCurr] = useState(false)
  const [showNew, setShowNew] = useState(false)
  const [showConf, setShowConf] = useState(false)
  const [savingPassword, setSavingPassword] = useState(false)

  // ── Email ──
  const [newEmail, setNewEmail] = useState('')
  const [emailPassword, setEmailPassword] = useState('')
  const [showEmailPass, setShowEmailPass] = useState(false)
  const [savingEmail, setSavingEmail] = useState(false)

  // ── Delete Account ──
  const [deleteConfirm, setDeleteConfirm] = useState('')
  const [deletePassword, setDeletePassword] = useState('')
  const [showDeletePass, setShowDeletePass] = useState(false)
  const [deleting, setDeleting] = useState(false)
  const [showDeleteModal, setShowDeleteModal] = useState(false)

  // ── Toasts ──
  const [toasts, setToasts] = useState<Toast[]>([])

  const showToast = useCallback((message: string, type: ToastType = 'info') => {
    const id = Math.random().toString(36).slice(2)
    setToasts(prev => [...prev, { id, message, type }])
    setTimeout(() => {
      setToasts(prev => prev.filter(t => t.id !== id))
    }, 4000)
  }, [])

  // Fetch settings with fallback to Supabase direct
  useEffect(() => {
    if (!user) return
    const fetchSettings = async () => {
      setLoading(true)
      try {
        const { data: sessionData } = await supabase.auth.getSession()
        const token = sessionData.session?.access_token
        if (!token) return
        const res = await fetch(`${API_BASE}/api/user-settings`, {
          headers: { Authorization: `Bearer ${token}` }
        })
        const data = await res.json()
        if (res.ok) {
          setSettings(data)
        } else {
          // Fallback: fetch from Supabase directly
          const { data: profileData } = await supabase
            .from('profiles')
            .select('full_name, avatar_url, created_at')
            .eq('id', user.id)
            .single()
          setSettings({
            email: user.email || '',
            full_name: profileData?.full_name || '',
            phone: '',
            bio: '',
            location: '',
            website: '',
            theme: 'dark',
            notifications_enabled: true,
            language: 'en',
            created_at: profileData?.created_at || '',
            updated_at: '',
          })
          showToast('Some features require migration 002. Run it in Supabase SQL Editor.', 'info')
        }
      } catch {
        // Network error: fallback to Supabase direct
        const { data: profileData } = await supabase
          .from('profiles')
          .select('full_name, avatar_url, created_at')
          .eq('id', user.id)
          .single()
        setSettings({
          email: user.email || '',
          full_name: profileData?.full_name || '',
          phone: '',
          bio: '',
          location: '',
          website: '',
          theme: 'dark',
          notifications_enabled: true,
          language: 'en',
          created_at: profileData?.created_at || '',
          updated_at: '',
        })
      } finally {
        setLoading(false)
      }
    }
    fetchSettings()
  }, [user, showToast])

  const handleProfileChange = (field: keyof AccountSettings, value: string | boolean) => {
    setSettings(prev => prev ? { ...prev, [field]: value } : null)
  }

  const saveProfile = async () => {
    if (!settings || !user) return
    setSavingProfile(true)
    try {
      const { data: sessionData } = await supabase.auth.getSession()
      const token = sessionData.session?.access_token
      const res = await fetch(`${API_BASE}/api/user-settings`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${token}`,
        },
        body: JSON.stringify({
          action: 'update_profile',
          full_name: settings.full_name,
          phone: settings.phone,
          bio: settings.bio,
          location: settings.location,
          website: settings.website,
          theme: settings.theme,
          notifications_enabled: settings.notifications_enabled,
          language: settings.language,
        }),
      })
      if (res.ok) {
        showToast('Profile saved successfully', 'success')
      } else {
        const err = await res.json()
        showToast(err.error || 'Failed to save profile', 'error')
      }
    } catch {
      showToast('Network error', 'error')
    } finally {
      setSavingProfile(false)
    }
  }

  const changePassword = async () => {
    if (newPassword !== confirmPassword) {
      showToast('Passwords do not match', 'error')
      return
    }
    if (newPassword.length < 8) {
      showToast('Password must be at least 8 characters', 'error')
      return
    }
    setSavingPassword(true)
    try {
      const { data: sessionData } = await supabase.auth.getSession()
      const token = sessionData.session?.access_token
      const res = await fetch(`${API_BASE}/api/user-settings`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${token}`,
        },
        body: JSON.stringify({
          action: 'change_password',
          current_password: currentPassword,
          new_password: newPassword,
        }),
      })
      const data = await res.json()
      if (res.ok) {
        showToast(data.message || 'Password changed', 'success')
        setCurrentPassword('')
        setNewPassword('')
        setConfirmPassword('')
      } else {
        showToast(data.error || 'Failed to change password', 'error')
      }
    } catch {
      showToast('Network error', 'error')
    } finally {
      setSavingPassword(false)
    }
  }

  const changeEmail = async () => {
    if (!newEmail || !emailPassword) {
      showToast('All fields are required', 'error')
      return
    }
    setSavingEmail(true)
    try {
      const { data: sessionData } = await supabase.auth.getSession()
      const token = sessionData.session?.access_token
      const res = await fetch(`${API_BASE}/api/user-settings`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${token}`,
        },
        body: JSON.stringify({
          action: 'change_email',
          current_password: emailPassword,
          new_email: newEmail,
        }),
      })
      const data = await res.json()
      if (res.ok) {
        showToast(data.message || 'Email updated', 'success')
        setNewEmail('')
        setEmailPassword('')
        if (settings) setSettings({ ...settings, email: newEmail })
      } else {
        showToast(data.error || 'Failed to change email', 'error')
      }
    } catch {
      showToast('Network error', 'error')
    } finally {
      setSavingEmail(false)
    }
  }

  const deleteAccount = async () => {
    if (deleteConfirm !== 'DELETE') {
      showToast('Type DELETE to confirm', 'error')
      return
    }
    setDeleting(true)
    try {
      const { data: sessionData } = await supabase.auth.getSession()
      const token = sessionData.session?.access_token
      const res = await fetch(`${API_BASE}/api/user-settings`, {
        method: 'DELETE',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${token}`,
        },
        body: JSON.stringify({ password: deletePassword }),
      })
      const data = await res.json()
      if (res.ok) {
        showToast(data.message || 'Account deleted', 'success')
        await signOut()
        navigate('/')
      } else {
        showToast(data.error || 'Failed to delete account', 'error')
      }
    } catch {
      showToast('Network error', 'error')
    } finally {
      setDeleting(false)
    }
  }

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <Loader2 className="w-6 h-6 animate-spin text-accent" />
      </div>
    )
  }

  if (!settings) {
    return <div className="text-sm text-danger">Failed to load settings.</div>
  }

  // ── Components ──
  const SectionCard = ({ title, icon: Icon, children, danger }: { title: string; icon: any; children: React.ReactNode; danger?: boolean }) => (
    <div className={`bg-surface border rounded p-6 ${danger ? 'border-danger/30' : 'border-border'}`}>
      <div className="flex items-center gap-2 mb-5">
        <Icon className={`w-5 h-5 ${danger ? 'text-danger' : 'text-accent'}`} />
        <h2 className={`text-lg font-semibold ${danger ? 'text-danger' : 'text-text-primary'}`}>{title}</h2>
      </div>
      {children}
    </div>
  )

  const InputField = ({ label, value, onChange, type = 'text', placeholder, icon: Icon, maxLength }: any) => (
    <div>
      <label className="block text-sm font-medium text-text-secondary mb-1.5">{label}</label>
      <div className="relative">
        {Icon && (
          <div className="absolute left-3 top-1/2 -translate-y-1/2 text-text-secondary">
            <Icon className="w-4 h-4" />
          </div>
        )}
        <input
          type={type}
          value={value || ''}
          onChange={(e) => onChange(e.target.value)}
          placeholder={placeholder}
          maxLength={maxLength}
          className={`w-full px-3 py-2 bg-background border border-border rounded text-text-primary text-sm focus:border-accent transition-colors ${Icon ? 'pl-10' : ''}`}
        />
      </div>
    </div>
  )

  const PasswordField = ({ label, value, onChange, show, setShow, placeholder }: any) => (
    <div>
      <label className="block text-sm font-medium text-text-secondary mb-1.5">{label}</label>
      <div className="relative">
        <input
          type={show ? 'text' : 'password'}
          value={value}
          onChange={(e) => onChange(e.target.value)}
          placeholder={placeholder}
          className="w-full px-3 py-2 pr-10 bg-background border border-border rounded text-text-primary text-sm focus:border-accent transition-colors"
        />
        <button
          type="button"
          onClick={() => setShow(!show)}
          className="absolute right-2 top-1/2 -translate-y-1/2 text-text-secondary hover:text-text-primary"
        >
          {show ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
        </button>
      </div>
    </div>
  )

  return (
    <div className="max-w-3xl space-y-6 relative">
      {/* Toasts */}
      <div className="fixed top-4 right-4 z-50 space-y-2">
        {toasts.map(t => (
          <div
            key={t.id}
            className={`px-4 py-3 rounded text-sm font-medium shadow-lg animate-fade-in ${
              t.type === 'success' ? 'bg-success/10 border border-success/20 text-success' :
              t.type === 'error' ? 'bg-danger/10 border border-danger/20 text-danger' :
              'bg-surface border border-border text-text-primary'
            }`}
          >
            {t.message}
          </div>
        ))}
      </div>

      {/* Header */}
      <div>
        <h1 className="text-2xl font-bold text-text-primary">Settings</h1>
        <p className="text-sm text-text-secondary mt-1">Manage your profile, security, and preferences.</p>
      </div>

      {/* Profile */}
      <SectionCard title="Profile" icon={User}>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <InputField label="Full name" value={settings.full_name} onChange={(v: string) => handleProfileChange('full_name', v)} placeholder="John Doe" icon={User} />
          <InputField label="Phone" value={settings.phone} onChange={(v: string) => handleProfileChange('phone', v)} placeholder="+1 555 000 0000" icon={Phone} />
          <InputField label="Location" value={settings.location} onChange={(v: string) => handleProfileChange('location', v)} placeholder="San Francisco, CA" icon={MapPin} />
          <InputField label="Website" value={settings.website} onChange={(v: string) => handleProfileChange('website', v)} placeholder="https://example.com" icon={Globe} />
        </div>
        <div className="mt-4">
          <label className="block text-sm font-medium text-text-secondary mb-1.5">Bio</label>
          <textarea
            value={settings.bio || ''}
            onChange={(e) => handleProfileChange('bio', e.target.value)}
            placeholder="A short bio about yourself..."
            maxLength={500}
            rows={3}
            className="w-full px-3 py-2 bg-background border border-border rounded text-text-primary text-sm focus:border-accent transition-colors resize-none"
          />
          <p className="text-xs text-text-secondary mt-1">{(settings.bio?.length || 0)}/500 characters</p>
        </div>
        <div className="mt-4">
          <button
            onClick={saveProfile}
            disabled={savingProfile}
            className="flex items-center gap-2 px-4 py-2 rounded text-sm font-medium bg-accent text-background hover:bg-accent-hover transition-colors disabled:opacity-50"
          >
            {savingProfile ? <Loader2 className="w-4 h-4 animate-spin" /> : <Save className="w-4 h-4" />}
            {savingProfile ? 'Saving...' : 'Save profile'}
          </button>
        </div>
      </SectionCard>

      {/* Preferences */}
      <SectionCard title="Preferences" icon={Moon}>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          {/* Theme */}
          <div>
            <label className="block text-sm font-medium text-text-secondary mb-1.5">Theme</label>
            <div className="grid grid-cols-2 gap-2">
              {THEMES.map(t => (
                <button
                  key={t.code}
                  onClick={() => handleProfileChange('theme', t.code)}
                  className={`flex items-center gap-2 px-3 py-2 rounded border text-sm transition-colors ${
                    settings.theme === t.code
                      ? 'border-accent bg-accent/10 text-accent'
                      : 'border-border bg-background text-text-secondary hover:border-text-secondary'
                  }`}
                >
                  <t.icon className="w-4 h-4" />
                  {t.label}
                </button>
              ))}
            </div>
          </div>

          {/* Language */}
          <div>
            <label className="block text-sm font-medium text-text-secondary mb-1.5">Language</label>
            <div className="relative">
              <Languages className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-text-secondary" />
              <select
                value={settings.language}
                onChange={(e) => handleProfileChange('language', e.target.value)}
                className="w-full pl-10 pr-8 py-2 bg-background border border-border rounded text-text-primary text-sm focus:border-accent transition-colors appearance-none cursor-pointer"
              >
                {LANGUAGES.map(l => (
                  <option key={l.code} value={l.code}>{l.label}</option>
                ))}
              </select>
              <ChevronDown className="absolute right-3 top-1/2 -translate-y-1/2 w-4 h-4 text-text-secondary pointer-events-none" />
            </div>
          </div>
        </div>

        {/* Notifications */}
        <div className="mt-4 flex items-center gap-3">
          <button
            onClick={() => handleProfileChange('notifications_enabled', !settings.notifications_enabled)}
            className={`relative w-11 h-6 rounded-full transition-colors ${settings.notifications_enabled ? 'bg-accent' : 'bg-border'}`}
          >
            <span className={`absolute top-1 left-1 w-4 h-4 rounded-full bg-background transition-transform ${settings.notifications_enabled ? 'translate-x-5' : 'translate-x-0'}`} />
          </button>
          <div className="flex items-center gap-2">
            <Bell className="w-4 h-4 text-text-secondary" />
            <span className="text-sm text-text-primary">Email notifications</span>
          </div>
        </div>
      </SectionCard>

      {/* Account Security */}
      <SectionCard title="Account Security" icon={Shield}>
        <div className="space-y-6">
          {/* Change Email */}
          <div className="border-b border-border pb-6">
            <h3 className="text-sm font-semibold text-text-primary mb-3">Change Email</h3>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <label className="block text-sm font-medium text-text-secondary mb-1.5">Current email</label>
                <div className="flex items-center gap-2 px-3 py-2 bg-elevated border border-border rounded text-sm text-text-secondary">
                  <Mail className="w-4 h-4" />
                  {settings.email}
                </div>
              </div>
              <InputField label="New email" value={newEmail} onChange={setNewEmail} type="email" placeholder="new@example.com" icon={Mail} />
            </div>
            <div className="mt-3">
              <PasswordField label="Current password" value={emailPassword} onChange={setEmailPassword} show={showEmailPass} setShow={setShowEmailPass} placeholder="Required to change email" />
            </div>
            <div className="mt-3">
              <button
                onClick={changeEmail}
                disabled={savingEmail || !newEmail || !emailPassword}
                className="flex items-center gap-2 px-4 py-2 rounded text-sm font-medium bg-accent text-background hover:bg-accent-hover transition-colors disabled:opacity-50"
              >
                {savingEmail ? <Loader2 className="w-4 h-4 animate-spin" /> : <Mail className="w-4 h-4" />}
                {savingEmail ? 'Updating...' : 'Update email'}
              </button>
            </div>
          </div>

          {/* Change Password */}
          <div>
            <h3 className="text-sm font-semibold text-text-primary mb-3">Change Password</h3>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <PasswordField label="Current password" value={currentPassword} onChange={setCurrentPassword} show={showCurr} setShow={setShowCurr} placeholder="Your current password" />
              <PasswordField label="New password" value={newPassword} onChange={setNewPassword} show={showNew} setShow={setShowNew} placeholder="Min 8 characters" />
              <PasswordField label="Confirm password" value={confirmPassword} onChange={setConfirmPassword} show={showConf} setShow={setShowConf} placeholder="Repeat new password" />
            </div>
            <div className="mt-3">
              <button
                onClick={changePassword}
                disabled={savingPassword || !currentPassword || !newPassword || !confirmPassword}
                className="flex items-center gap-2 px-4 py-2 rounded text-sm font-medium bg-accent text-background hover:bg-accent-hover transition-colors disabled:opacity-50"
              >
                {savingPassword ? <Loader2 className="w-4 h-4 animate-spin" /> : <Lock className="w-4 h-4" />}
                {savingPassword ? 'Updating...' : 'Update password'}
              </button>
            </div>
          </div>
        </div>
      </SectionCard>

      {/* Danger Zone */}
      <SectionCard title="Danger Zone" icon={AlertTriangle} danger>
        <div className="space-y-4">
          <p className="text-sm text-danger/80">
            Deleting your account is permanent. All webhooks, logs, and data will be removed forever.
          </p>
          <button
            onClick={() => setShowDeleteModal(true)}
            className="flex items-center gap-2 px-4 py-2 rounded text-sm font-medium bg-danger/10 text-danger hover:bg-danger/20 transition-colors border border-danger/20"
          >
            <Trash2 className="w-4 h-4" />
            Delete account
          </button>
        </div>
      </SectionCard>

      {/* Delete Account Modal */}
      {showDeleteModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/70">
          <div className="bg-surface border border-danger/30 rounded-lg p-6 w-full max-w-md mx-4">
            <div className="flex items-center gap-2 mb-4">
              <AlertTriangle className="w-5 h-5 text-danger" />
              <h3 className="text-lg font-semibold text-danger">Delete Account</h3>
            </div>
            <p className="text-sm text-text-secondary mb-4">
              This action cannot be undone. Type <strong className="text-text-primary">DELETE</strong> to confirm.
            </p>
            <div className="space-y-3">
              <input
                type="text"
                value={deleteConfirm}
                onChange={(e) => setDeleteConfirm(e.target.value)}
                placeholder="Type DELETE"
                className="w-full px-3 py-2 bg-background border border-danger/30 rounded text-text-primary text-sm focus:border-danger transition-colors"
              />
              <PasswordField
                label="Your password"
                value={deletePassword}
                onChange={setDeletePassword}
                show={showDeletePass}
                setShow={setShowDeletePass}
                placeholder="Required to delete account"
              />
            </div>
            <div className="flex items-center gap-3 mt-5">
              <button
                onClick={() => { setShowDeleteModal(false); setDeleteConfirm(''); setDeletePassword('') }}
                className="px-4 py-2 rounded text-sm font-medium bg-surface border border-border text-text-primary hover:bg-elevated transition-colors"
              >
                Cancel
              </button>
              <button
                onClick={deleteAccount}
                disabled={deleting || deleteConfirm !== 'DELETE' || !deletePassword}
                className="flex items-center gap-2 px-4 py-2 rounded text-sm font-medium bg-danger text-white hover:bg-danger/90 transition-colors disabled:opacity-50"
              >
                {deleting ? <Loader2 className="w-4 h-4 animate-spin" /> : <Trash2 className="w-4 h-4" />}
                {deleting ? 'Deleting...' : 'Delete permanently'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
