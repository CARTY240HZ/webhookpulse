import { useState, useEffect, useCallback } from 'react'
import { useNavigate } from 'react-router-dom'
import { useAuth } from '../hooks/useAuth'
import { useTheme } from '../hooks/useTheme'
import { supabase } from '../lib/supabase'
import { t, setLang, getLang, type LangCode } from '../i18n'
import type { AccountSettings } from '../types'
import {
  User, Phone, MapPin, Mail, Lock, Trash2, Save,
  Loader2, AlertTriangle, Eye, EyeOff, Moon, Sun, Bell,
  Languages, ChevronDown, Shield, KeyRound, Smartphone, Check
} from 'lucide-react'

const API_BASE = import.meta.env.VITE_API_URL || ''

type ToastType = 'success' | 'error' | 'info'
interface Toast { id: string; message: string; type: ToastType }

const LANGUAGES: { code: LangCode; label: string }[] = [
  { code: 'en', label: 'English' },
  { code: 'es', label: 'Español' },
]

export default function SettingsPage() {
  const { user } = useAuth()
  const { theme, toggleTheme } = useTheme()
  const navigate = useNavigate()
  const [lang, setLangState] = useState<LangCode>(getLang())

  // Profile
  const [settings, setSettings] = useState<AccountSettings | null>(null)
  const [loading, setLoading] = useState(true)
  const [savingProfile, setSavingProfile] = useState(false)

  // Password
  const [currPass, setCurrPass] = useState('')
  const [newPass, setNewPass] = useState('')
  const [confPass, setConfPass] = useState('')
  const [showCurr, setShowCurr] = useState(false)
  const [showNew, setShowNew] = useState(false)
  const [showConf, setShowConf] = useState(false)
  const [savingPass, setSavingPass] = useState(false)

  // Email
  const [newEmail, setNewEmail] = useState('')
  const [emailPass, setEmailPass] = useState('')
  const [showEmailPass, setShowEmailPass] = useState(false)
  const [savingEmail, setSavingEmail] = useState(false)

  // 2FA
  const [phone2FA, setPhone2FA] = useState('')
  const [code2FA, setCode2FA] = useState('')
  const [sendingCode, setSendingCode] = useState(false)
  const [verifyingCode, setVerifyingCode] = useState(false)
  const [twoFAEnabled, setTwoFAEnabled] = useState(false)
  const [showCodeInput, setShowCodeInput] = useState(false)

  // Delete
  const [deleteConfirm, setDeleteConfirm] = useState('')
  const [deletePass, setDeletePass] = useState('')
  const [showDeletePass, setShowDeletePass] = useState(false)
  const [deleting, setDeleting] = useState(false)
  const [showDeleteModal, setShowDeleteModal] = useState(false)

  // Toasts
  const [toasts, setToasts] = useState<Toast[]>([])
  const showToast = useCallback((msg: string, type: ToastType = 'info') => {
    const id = Math.random().toString(36).slice(2)
    setToasts(p => [...p, { id, message: msg, type }])
    setTimeout(() => setToasts(p => p.filter(t => t.id !== id)), 4000)
  }, [])

  // Fetch settings
  useEffect(() => {
    if (!user) return
    const fetchSettings = async () => {
      setLoading(true)
      try {
        const { data: s } = await supabase.auth.getSession()
        const token = s.session?.access_token
        if (!token) { setLoading(false); return }
        const res = await fetch(`${API_BASE}/api/user-settings`, {
          headers: { Authorization: `Bearer ${token}` }
        })
        const data = await res.json()
        if (res.ok) {
          setSettings(data)
          setTwoFAEnabled(data.phone_verified === true)
          if (data.phone) setPhone2FA(data.phone)
        } else {
          // Fallback
          const { data: p } = await supabase.from('profiles').select('full_name, created_at').eq('id', user.id).single()
          setSettings({
            email: user.email || '', full_name: p?.full_name || '', phone: '', location: '',
            theme: 'dark', notifications_enabled: true, language: 'en',
            created_at: p?.created_at || '', updated_at: '',
          })
        }
      } catch {
        showToast(t('common.error'), 'error')
      } finally { setLoading(false) }
    }
    fetchSettings()
  }, [user, showToast])

  const handleChange = (field: keyof AccountSettings, value: string | boolean) => {
    setSettings(p => p ? { ...p, [field]: value } : null)
  }

  const handleLangChange = (code: LangCode) => {
    setLangState(code)
    setLang(code)
    showToast(t('common.success'), 'success')
  }

  const saveProfile = async () => {
    if (!settings || !user) return
    setSavingProfile(true)
    try {
      const { data: s } = await supabase.auth.getSession()
      const token = s.session?.access_token
      const res = await fetch(`${API_BASE}/api/user-settings`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
        body: JSON.stringify({
          action: 'update_profile',
          full_name: settings.full_name,
          phone: settings.phone,
          location: settings.location,
          theme: settings.theme,
          notifications_enabled: settings.notifications_enabled,
          language: settings.language,
        }),
      })
      if (res.ok) showToast(t('common.success'), 'success')
      else showToast(t('common.error'), 'error')
    } catch { showToast(t('common.error'), 'error') }
    finally { setSavingProfile(false) }
  }

  const changePassword = async () => {
    if (newPass !== confPass) { showToast('Passwords do not match', 'error'); return }
    if (newPass.length < 8) { showToast(t('settings.passwordMin'), 'error'); return }
    setSavingPass(true)
    try {
      const { data: s } = await supabase.auth.getSession()
      const token = s.session?.access_token
      const res = await fetch(`${API_BASE}/api/user-settings`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
        body: JSON.stringify({ action: 'change_password', current_password: currPass, new_password: newPass }),
      })
      const data = await res.json()
      if (res.ok) {
        showToast(data.message || t('common.success'), 'success')
        setCurrPass(''); setNewPass(''); setConfPass('')
      } else showToast(data.error || t('common.error'), 'error')
    } catch { showToast(t('common.error'), 'error') }
    finally { setSavingPass(false) }
  }

  const changeEmail = async () => {
    if (!newEmail || !emailPass) { showToast('All fields required', 'error'); return }
    setSavingEmail(true)
    try {
      const { data: s } = await supabase.auth.getSession()
      const token = s.session?.access_token
      const res = await fetch(`${API_BASE}/api/user-settings`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
        body: JSON.stringify({ action: 'change_email', current_password: emailPass, new_email: newEmail }),
      })
      const data = await res.json()
      if (res.ok) {
        showToast(data.message || t('common.success'), 'success')
        setNewEmail(''); setEmailPass('')
      } else showToast(data.error || t('common.error'), 'error')
    } catch { showToast(t('common.error'), 'error') }
    finally { setSavingEmail(false) }
  }

  // 2FA
  const send2FACode = async () => {
    if (!phone2FA || phone2FA.length < 8) { showToast('Enter a valid phone number', 'error'); return }
    setSendingCode(true)
    try {
      const { data: s } = await supabase.auth.getSession()
      const token = s.session?.access_token
      const res = await fetch(`${API_BASE}/api/2fa-send`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
        body: JSON.stringify({ phone: phone2FA }),
      })
      const data = await res.json()
      if (res.ok) {
        setShowCodeInput(true)
        showToast('Code sent to your phone', 'success')
      } else showToast(data.error || 'Failed to send code', 'error')
    } catch { showToast(t('common.error'), 'error') }
    finally { setSendingCode(false) }
  }

  const verify2FA = async () => {
    if (!code2FA || code2FA.length !== 6) { showToast('Enter 6-digit code', 'error'); return }
    setVerifyingCode(true)
    try {
      const { data: s } = await supabase.auth.getSession()
      const token = s.session?.access_token
      const res = await fetch(`${API_BASE}/api/2fa-verify`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
        body: JSON.stringify({ phone: phone2FA, code: code2FA }),
      })
      const data = await res.json()
      if (res.ok) {
        setTwoFAEnabled(true)
        setShowCodeInput(false)
        setCode2FA('')
        showToast(t('settings.2fa.success'), 'success')
      } else showToast(data.error || t('settings.2fa.invalidCode'), 'error')
    } catch { showToast(t('common.error'), 'error') }
    finally { setVerifyingCode(false) }
  }

  const deleteAccount = async () => {
    if (deleteConfirm !== 'DELETE') { showToast('Type DELETE', 'error'); return }
    setDeleting(true)
    try {
      const { data: s } = await supabase.auth.getSession()
      const token = s.session?.access_token
      const res = await fetch(`${API_BASE}/api/user-settings`, {
        method: 'DELETE',
        headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
        body: JSON.stringify({ password: deletePass }),
      })
      const data = await res.json()
      if (res.ok) {
        showToast(data.message || 'Deleted', 'success')
        await supabase.auth.signOut()
        navigate('/')
      } else showToast(data.error || t('common.error'), 'error')
    } catch { showToast(t('common.error'), 'error') }
    finally { setDeleting(false) }
  }

  if (loading) return <div className="flex items-center justify-center h-64"><Loader2 className="w-6 h-6 animate-spin text-accent" /></div>
  if (!settings) return <div className="text-sm text-danger">Failed to load settings.</div>

  const Card = ({ title, icon: Icon, children, danger }: any) => (
    <div className={`bg-surface border rounded p-6 ${danger ? 'border-danger/30' : 'border-border'}`}>
      <div className="flex items-center gap-2 mb-5">
        <Icon className={`w-5 h-5 ${danger ? 'text-danger' : 'text-accent'}`} />
        <h2 className={`text-lg font-semibold ${danger ? 'text-danger' : 'text-text-primary'}`}>{title}</h2>
      </div>
      {children}
    </div>
  )

  const Input = ({ label, value, onChange, type = 'text', placeholder, icon: Icon }: any) => (
    <div>
      <label className="block text-sm font-medium text-text-secondary mb-1.5">{label}</label>
      <div className="relative">
        {Icon && <div className="absolute left-3 top-1/2 -translate-y-1/2 text-text-secondary"><Icon className="w-4 h-4" /></div>}
        <input type={type} value={value || ''} onChange={(e) => onChange(e.target.value)} placeholder={placeholder}
          className={`w-full px-3 py-2 bg-background border border-border rounded text-text-primary text-sm focus:border-accent transition-colors ${Icon ? 'pl-10' : ''}`} />
      </div>
    </div>
  )

  const PassInput = ({ label, value, onChange, show, setShow, placeholder }: any) => (
    <div>
      <label className="block text-sm font-medium text-text-secondary mb-1.5">{label}</label>
      <div className="relative">
        <input type={show ? 'text' : 'password'} value={value} onChange={(e) => onChange(e.target.value)} placeholder={placeholder}
          className="w-full px-3 py-2 pr-10 bg-background border border-border rounded text-text-primary text-sm focus:border-accent transition-colors" />
        <button type="button" onClick={() => setShow(!show)} className="absolute right-2 top-1/2 -translate-y-1/2 text-text-secondary hover:text-text-primary">
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
          <div key={t.id} className={`px-4 py-3 rounded text-sm font-medium shadow-lg animate-fade-in ${
            t.type === 'success' ? 'bg-success/10 border border-success/20 text-success' :
            t.type === 'error' ? 'bg-danger/10 border border-danger/20 text-danger' :
            'bg-surface border border-border text-text-primary'
          }`}>{t.message}</div>
        ))}
      </div>

      <div>
        <h1 className="text-2xl font-bold text-text-primary">{t('settings.title')}</h1>
        <p className="text-sm text-text-secondary mt-1">{t('settings.subtitle')}</p>
      </div>

      {/* Profile */}
      <Card title={t('settings.profile')} icon={User}>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <Input label={t('settings.fullName')} value={settings.full_name} onChange={(v: string) => handleChange('full_name', v)} placeholder="John Doe" icon={User} />
          <Input label={t('settings.phone')} value={settings.phone} onChange={(v: string) => handleChange('phone', v)} placeholder={t('settings.2fa.phonePlaceholder')} icon={Phone} />
          <Input label={t('settings.location')} value={settings.location} onChange={(v: string) => handleChange('location', v)} placeholder="San Francisco, CA" icon={MapPin} />
        </div>
        <div className="mt-4">
          <button onClick={saveProfile} disabled={savingProfile}
            className="flex items-center gap-2 px-4 py-2 rounded text-sm font-medium bg-accent text-background hover:bg-accent-hover transition-colors disabled:opacity-50">
            {savingProfile ? <Loader2 className="w-4 h-4 animate-spin" /> : <Save className="w-4 h-4" />}
            {savingProfile ? t('settings.saving') : t('settings.saveProfile')}
          </button>
        </div>
      </Card>

      {/* Preferences */}
      <Card title={t('settings.preferences')} icon={Moon}>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          {/* Theme */}
          <div>
            <label className="block text-sm font-medium text-text-secondary mb-1.5">{t('settings.theme')}</label>
            <div className="grid grid-cols-2 gap-2">
              <button onClick={() => { if (theme !== 'dark') toggleTheme() }}
                className={`flex items-center gap-2 px-3 py-2 rounded border text-sm transition-colors ${
                  theme === 'dark' ? 'border-accent bg-accent/10 text-accent' : 'border-border bg-background text-text-secondary hover:border-text-secondary'
                }`}>
                <Moon className="w-4 h-4" /> Dark
              </button>
              <button onClick={() => { if (theme !== 'light') toggleTheme() }}
                className={`flex items-center gap-2 px-3 py-2 rounded border text-sm transition-colors ${
                  theme === 'light' ? 'border-accent bg-accent/10 text-accent' : 'border-border bg-background text-text-secondary hover:border-text-secondary'
                }`}>
                <Sun className="w-4 h-4" /> Light
              </button>
            </div>
          </div>

          {/* Language */}
          <div>
            <label className="block text-sm font-medium text-text-secondary mb-1.5">{t('settings.language')}</label>
            <div className="relative">
              <Languages className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-text-secondary" />
              <select value={lang} onChange={(e) => handleLangChange(e.target.value as LangCode)}
                className="w-full pl-10 pr-8 py-2 bg-background border border-border rounded text-text-primary text-sm focus:border-accent transition-colors appearance-none cursor-pointer">
                {LANGUAGES.map(l => <option key={l.code} value={l.code}>{l.label}</option>)}
              </select>
              <ChevronDown className="absolute right-3 top-1/2 -translate-y-1/2 w-4 h-4 text-text-secondary pointer-events-none" />
            </div>
          </div>
        </div>

        {/* Notifications */}
        <div className="mt-4 flex items-center gap-3">
          <button onClick={() => handleChange('notifications_enabled', !settings.notifications_enabled)}
            className={`relative w-11 h-6 rounded-full transition-colors ${settings.notifications_enabled ? 'bg-accent' : 'bg-border'}`}>
            <span className={`absolute top-1 left-1 w-4 h-4 rounded-full bg-background transition-transform ${settings.notifications_enabled ? 'translate-x-5' : 'translate-x-0'}`} />
          </button>
          <div className="flex items-center gap-2">
            <Bell className="w-4 h-4 text-text-secondary" />
            <span className="text-sm text-text-primary">{t('settings.notifications')}</span>
          </div>
        </div>
      </Card>

      {/* Account Security */}
      <Card title={t('settings.security')} icon={Shield}>
        <div className="space-y-6">
          {/* 2FA */}
          <div className="border-b border-border pb-6">
            <div className="flex items-center gap-2 mb-3">
              <Smartphone className="w-5 h-5 text-accent" />
              <h3 className="text-sm font-semibold text-text-primary">{t('settings.2fa.title')}</h3>
              {twoFAEnabled && <span className="ml-2 inline-flex items-center gap-1 px-2 py-0.5 rounded text-xs font-medium bg-success/10 text-success"><Check className="w-3 h-3" />{t('settings.2fa.enabled')}</span>}
            </div>
            <p className="text-sm text-text-secondary mb-3">{t('settings.2fa.description')}</p>
            {!twoFAEnabled ? (
              <div className="space-y-3">
                <div className="flex items-center gap-2">
                  <div className="relative flex-1">
                    <Phone className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-text-secondary" />
                    <input type="tel" value={phone2FA} onChange={(e) => setPhone2FA(e.target.value)} placeholder={t('settings.2fa.phonePlaceholder')}
                      className="w-full pl-10 pr-3 py-2 bg-background border border-border rounded text-text-primary text-sm focus:border-accent transition-colors" />
                  </div>
                  <button onClick={send2FACode} disabled={sendingCode || !phone2FA}
                    className="px-4 py-2 rounded text-sm font-medium bg-accent text-background hover:bg-accent-hover transition-colors disabled:opacity-50 shrink-0">
                    {sendingCode ? t('settings.2fa.sending') : t('settings.2fa.sendCode')}
                  </button>
                </div>
                {showCodeInput && (
                  <div className="flex items-center gap-2">
                    <div className="relative flex-1">
                      <KeyRound className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-text-secondary" />
                      <input type="text" value={code2FA} onChange={(e) => setCode2FA(e.target.value.replace(/\D/g, '').slice(0, 6))} placeholder={t('settings.2fa.codePlaceholder')} maxLength={6}
                        className="w-full pl-10 pr-3 py-2 bg-background border border-border rounded text-text-primary text-sm focus:border-accent transition-colors" />
                    </div>
                    <button onClick={verify2FA} disabled={verifyingCode || code2FA.length !== 6}
                      className="px-4 py-2 rounded text-sm font-medium bg-success text-white hover:bg-success/90 transition-colors disabled:opacity-50 shrink-0">
                      {verifyingCode ? t('settings.2fa.verifying') : t('settings.2fa.verifyCode')}
                    </button>
                  </div>
                )}
              </div>
            ) : (
              <div className="flex items-center gap-2 text-sm text-success">
                <Check className="w-4 h-4" />
                <span>2FA is active on {phone2FA}</span>
              </div>
            )}
          </div>

          {/* Change Email */}
          <div className="border-b border-border pb-6">
            <h3 className="text-sm font-semibold text-text-primary mb-3">{t('settings.changeEmail')}</h3>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <label className="block text-sm font-medium text-text-secondary mb-1.5">{t('settings.currentEmail')}</label>
                <div className="flex items-center gap-2 px-3 py-2 bg-elevated border border-border rounded text-sm text-text-secondary">
                  <Mail className="w-4 h-4" /> {settings.email}
                </div>
              </div>
              <Input label={t('settings.newEmail')} value={newEmail} onChange={setNewEmail} type="email" placeholder="new@example.com" icon={Mail} />
            </div>
            <div className="mt-3">
              <PassInput label={t('settings.currentPassword')} value={emailPass} onChange={setEmailPass} show={showEmailPass} setShow={setShowEmailPass} placeholder="Required" />
            </div>
            <div className="mt-3">
              <button onClick={changeEmail} disabled={savingEmail || !newEmail || !emailPass}
                className="flex items-center gap-2 px-4 py-2 rounded text-sm font-medium bg-accent text-background hover:bg-accent-hover transition-colors disabled:opacity-50">
                {savingEmail ? <Loader2 className="w-4 h-4 animate-spin" /> : <Mail className="w-4 h-4" />}
                {savingEmail ? t('settings.saving') : t('settings.updateEmail')}
              </button>
            </div>
          </div>

          {/* Change Password */}
          <div>
            <h3 className="text-sm font-semibold text-text-primary mb-3">Change Password</h3>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <PassInput label={t('settings.currentPassword')} value={currPass} onChange={setCurrPass} show={showCurr} setShow={setShowCurr} placeholder="Your current password" />
              <PassInput label={t('settings.newPassword')} value={newPass} onChange={setNewPass} show={showNew} setShow={setShowNew} placeholder={t('settings.passwordMin)} />
              <PassInput label={t('settings.confirmPassword')} value={confPass} onChange={setConfPass} show={showConf} setShow={setShowConf} placeholder="Repeat" />
            </div>
            <div className="mt-3">
              <button onClick={changePassword} disabled={savingPass || !currPass || !newPass || !confPass}
                className="flex items-center gap-2 px-4 py-2 rounded text-sm font-medium bg-accent text-background hover:bg-accent-hover transition-colors disabled:opacity-50">
                {savingPass ? <Loader2 className="w-4 h-4 animate-spin" /> : <Lock className="w-4 h-4" />}
                {savingPass ? t('settings.saving') : t('settings.updatePassword')}
              </button>
            </div>
          </div>
        </div>
      </Card>

      {/* Danger Zone */}
      <Card title={t('settings.dangerZone')} icon={AlertTriangle} danger>
        <p className="text-sm text-danger/80 mb-4">{t('settings.deleteWarning')}</p>
        <button onClick={() => setShowDeleteModal(true)}
          className="flex items-center gap-2 px-4 py-2 rounded text-sm font-medium bg-danger/10 text-danger hover:bg-danger/20 transition-colors border border-danger/20">
          <Trash2 className="w-4 h-4" /> {t('settings.deleteAccount')}
        </button>
      </Card>

      {/* Delete Modal */}
      {showDeleteModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/70">
          <div className="bg-surface border border-danger/30 rounded-lg p-6 w-full max-w-md mx-4">
            <div className="flex items-center gap-2 mb-4">
              <AlertTriangle className="w-5 h-5 text-danger" />
              <h3 className="text-lg font-semibold text-danger">{t('settings.deleteAccount')}</h3>
            </div>
            <p className="text-sm text-text-secondary mb-4">{t('settings.deleteWarning')}</p>
            <div className="space-y-3">
              <input type="text" value={deleteConfirm} onChange={(e) => setDeleteConfirm(e.target.value)} placeholder={t('settings.deleteConfirm')}
                className="w-full px-3 py-2 bg-background border border-danger/30 rounded text-text-primary text-sm focus:border-danger transition-colors" />
              <PassInput label={t('settings.currentPassword')} value={deletePass} onChange={setDeletePass} show={showDeletePass} setShow={setShowDeletePass} placeholder="Required" />
            </div>
            <div className="flex items-center gap-3 mt-5">
              <button onClick={() => { setShowDeleteModal(false); setDeleteConfirm(''); setDeletePass('') }}
                className="px-4 py-2 rounded text-sm font-medium bg-surface border border-border text-text-primary hover:bg-elevated transition-colors">{t('settings.cancel')}</button>
              <button onClick={deleteAccount} disabled={deleting || deleteConfirm !== 'DELETE' || !deletePass}
                className="flex items-center gap-2 px-4 py-2 rounded text-sm font-medium bg-danger text-white hover:bg-danger/90 transition-colors disabled:opacity-50">
                {deleting ? <Loader2 className="w-4 h-4 animate-spin" /> : <Trash2 className="w-4 h-4" />}
                {deleting ? t('settings.saving') : t('settings.deletePermanent')}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
