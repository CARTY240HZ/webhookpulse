export type TranslationKey =
  | 'app.name'
  | 'nav.dashboard'
  | 'nav.stats'
  | 'nav.settings'
  | 'nav.logout'
  | 'nav.back'
  | 'nav.home'
  | 'settings.title'
  | 'settings.subtitle'
  | 'settings.profile'
  | 'settings.preferences'
  | 'settings.security'
  | 'settings.dangerZone'
  | 'settings.fullName'
  | 'settings.phone'
  | 'settings.location'
  | 'settings.bio'
  | 'settings.theme'
  | 'settings.language'
  | 'settings.notifications'
  | 'settings.changeEmail'
  | 'settings.currentEmail'
  | 'settings.newEmail'
  | 'settings.currentPassword'
  | 'settings.newPassword'
  | 'settings.confirmPassword'
  | 'settings.updateEmail'
  | 'settings.updatePassword'
  | 'settings.passwordMin'
  | 'settings.deleteAccount'
  | 'settings.deleteWarning'
  | 'settings.deleteConfirm'
  | 'settings.deletePermanent'
  | 'settings.cancel'
  | 'settings.saveProfile'
  | 'settings.saving'
  | 'settings.2fa.title'
  | 'settings.2fa.description'
  | 'settings.2fa.sendCode'
  | 'settings.2fa.verifyCode'
  | 'settings.2fa.codePlaceholder'
  | 'settings.2fa.phonePlaceholder'
  | 'settings.2fa.enabled'
  | 'settings.2fa.disabled'
  | 'settings.2fa.verifying'
  | 'settings.2fa.sending'
  | 'settings.2fa.success'
  | 'settings.2fa.invalidCode'
  | 'common.copy'
  | 'common.copied'
  | 'common.loading'
  | 'common.error'
  | 'common.success'
  | 'webhooks.title'
  | 'webhooks.new'
  | 'webhooks.active'
  | 'webhooks.inactive'
  | 'webhooks.messages'
  | 'webhooks.path'
  | 'webhooks.secret'
  | 'webhooks.native'
  | 'webhooks.discord'
  | 'login.title'
  | 'login.email'
  | 'login.password'
  | 'login.signIn'
  | 'login.noAccount'
  | 'login.register'
  | 'login.forgot'
  | 'register.title'
  | 'register.name'
  | 'register.createAccount'
  | 'register.hasAccount'
  | 'landing.hero'
  | 'landing.subtitle'
  | 'landing.startFree'
  | 'landing.signIn'
  | 'landing.goDashboard'
  | 'webhooks.templates.title'
  | 'webhooks.templates.playerJoin'
  | 'webhooks.templates.serverStats'
  | 'webhooks.templates.errorLogger'
  | 'webhooks.templates.adminCommand'
  | 'webhooks.templates.generate'
  | 'webhooks.templates.copy'
  | 'webhooks.templates.preview'

export const translations: Record<string, Record<TranslationKey, string>> = {
  en: {
    'app.name': 'WebhookPulse',
    'nav.dashboard': 'Dashboard',
    'nav.stats': 'Stats',
    'nav.settings': 'Settings',
    'nav.logout': 'Sign out',
    'nav.back': 'Back',
    'nav.home': 'Home',
    'settings.title': 'Settings',
    'settings.subtitle': 'Manage your profile, security, and preferences.',
    'settings.profile': 'Profile',
    'settings.preferences': 'Preferences',
    'settings.security': 'Account Security',
    'settings.dangerZone': 'Danger Zone',
    'settings.fullName': 'Full name',
    'settings.phone': 'Phone number',
    'settings.location': 'Location',
    'settings.bio': 'Bio',
    'settings.theme': 'Theme',
    'settings.language': 'Language',
    'settings.notifications': 'Email notifications',
    'settings.changeEmail': 'Change Email',
    'settings.currentEmail': 'Current email',
    'settings.newEmail': 'New email',
    'settings.currentPassword': 'Current password',
    'settings.newPassword': 'New password',
    'settings.confirmPassword': 'Confirm password',
    'settings.updateEmail': 'Update email',
    'settings.updatePassword': 'Update password',
    'settings.passwordMin': 'Min 8 characters',
    'settings.deleteAccount': 'Delete account',
    'settings.deleteWarning': 'Deleting your account is permanent. All webhooks, logs, and data will be removed forever.',
    'settings.deleteConfirm': 'Type DELETE to confirm',
    'settings.deletePermanent': 'Delete permanently',
    'settings.cancel': 'Cancel',
    'settings.saveProfile': 'Save profile',
    'settings.saving': 'Saving...',
    'settings.2fa.title': 'Two-Factor Authentication',
    'settings.2fa.description': 'Add an extra layer of security. Enter your phone to receive a verification code.',
    'settings.2fa.sendCode': 'Send verification code',
    'settings.2fa.verifyCode': 'Verify code',
    'settings.2fa.codePlaceholder': 'Enter 6-digit code',
    'settings.2fa.phonePlaceholder': '+1 555 000 0000',
    'settings.2fa.enabled': '2FA enabled',
    'settings.2fa.disabled': '2FA disabled',
    'settings.2fa.verifying': 'Verifying...',
    'settings.2fa.sending': 'Sending...',
    'settings.2fa.success': 'Phone verified. 2FA is now active.',
    'settings.2fa.invalidCode': 'Invalid code. Please try again.',
    'common.copy': 'Copy',
    'common.copied': 'Copied',
    'common.loading': 'Loading...',
    'common.error': 'Error',
    'common.success': 'Success',
    'webhooks.title': 'Webhooks',
    'webhooks.new': 'New webhook',
    'webhooks.active': 'Active',
    'webhooks.inactive': 'Inactive',
    'webhooks.messages': 'Messages received',
    'webhooks.path': 'Path',
    'webhooks.secret': 'Secret',
    'webhooks.native': 'Native',
    'webhooks.discord': 'Discord',
    'login.title': 'Sign in',
    'login.email': 'Email',
    'login.password': 'Password',
    'login.signIn': 'Sign in',
    'login.noAccount': "Don't have an account?",
    'login.register': 'Register',
    'login.forgot': 'Forgot password?',
    'register.title': 'Create account',
    'register.name': 'Full name',
    'register.createAccount': 'Create account',
    'register.hasAccount': 'Already have an account?',
    'landing.hero': 'Capture and inspect every webhook',
    'landing.subtitle': 'A professional receiver for Discord and generic webhooks. Real-time logs, secure secrets, and a dashboard built for precision.',
    'landing.startFree': 'Start for free',
    'landing.signIn': 'Sign in',
    'landing.goDashboard': 'Go to Dashboard',
    'webhooks.templates.title': 'Roblox Templates',
    'webhooks.templates.playerJoin': 'Player Join',
    'webhooks.templates.serverStats': 'Server Stats',
    'webhooks.templates.errorLogger': 'Error Logger',
    'webhooks.templates.adminCommand': 'Admin Command',
    'webhooks.templates.generate': 'Generate Lua Script',
    'webhooks.templates.copy': 'Copy Script',
    'webhooks.templates.preview': 'Preview',
  },
  es: {
    'app.name': 'WebhookPulse',
    'nav.dashboard': 'Panel',
    'nav.stats': 'Estadísticas',
    'nav.settings': 'Ajustes',
    'nav.logout': 'Cerrar sesión',
    'nav.back': 'Atrás',
    'nav.home': 'Inicio',
    'settings.title': 'Ajustes',
    'settings.subtitle': 'Gestiona tu perfil, seguridad y preferencias.',
    'settings.profile': 'Perfil',
    'settings.preferences': 'Preferencias',
    'settings.security': 'Seguridad de la Cuenta',
    'settings.dangerZone': 'Zona de Peligro',
    'settings.fullName': 'Nombre completo',
    'settings.phone': 'Número de teléfono',
    'settings.location': 'Ubicación',
    'settings.bio': 'Biografía',
    'settings.theme': 'Tema',
    'settings.language': 'Idioma',
    'settings.notifications': 'Notificaciones por email',
    'settings.changeEmail': 'Cambiar Email',
    'settings.currentEmail': 'Email actual',
    'settings.newEmail': 'Nuevo email',
    'settings.currentPassword': 'Contraseña actual',
    'settings.newPassword': 'Nueva contraseña',
    'settings.confirmPassword': 'Confirmar contraseña',
    'settings.updateEmail': 'Actualizar email',
    'settings.updatePassword': 'Actualizar contraseña',
    'settings.passwordMin': 'Mín 8 caracteres',
    'settings.deleteAccount': 'Eliminar cuenta',
    'settings.deleteWarning': 'Eliminar tu cuenta es permanente. Todos los webhooks, logs y datos serán eliminados para siempre.',
    'settings.deleteConfirm': 'Escribe DELETE para confirmar',
    'settings.deletePermanent': 'Eliminar permanentemente',
    'settings.cancel': 'Cancelar',
    'settings.saveProfile': 'Guardar perfil',
    'settings.saving': 'Guardando...',
    'settings.2fa.title': 'Autenticación de Dos Factores',
    'settings.2fa.description': 'Añade una capa extra de seguridad. Introduce tu teléfono para recibir un código de verificación.',
    'settings.2fa.sendCode': 'Enviar código',
    'settings.2fa.verifyCode': 'Verificar código',
    'settings.2fa.codePlaceholder': 'Introduce código de 6 dígitos',
    'settings.2fa.phonePlaceholder': '+34 600 000 000',
    'settings.2fa.enabled': '2FA activado',
    'settings.2fa.disabled': '2FA desactivado',
    'settings.2fa.verifying': 'Verificando...',
    'settings.2fa.sending': 'Enviando...',
    'settings.2fa.success': 'Teléfono verificado. 2FA ahora activo.',
    'settings.2fa.invalidCode': 'Código inválido. Inténtalo de nuevo.',
    'common.copy': 'Copiar',
    'common.copied': 'Copiado',
    'common.loading': 'Cargando...',
    'common.error': 'Error',
    'common.success': 'Éxito',
    'webhooks.title': 'Webhooks',
    'webhooks.new': 'Nuevo webhook',
    'webhooks.active': 'Activo',
    'webhooks.inactive': 'Inactivo',
    'webhooks.messages': 'Mensajes recibidos',
    'webhooks.path': 'Ruta',
    'webhooks.secret': 'Secreto',
    'webhooks.native': 'Nativo',
    'webhooks.discord': 'Discord',
    'login.title': 'Iniciar sesión',
    'login.email': 'Email',
    'login.password': 'Contraseña',
    'login.signIn': 'Iniciar sesión',
    'login.noAccount': '¿No tienes cuenta?',
    'login.register': 'Registrarse',
    'login.forgot': '¿Olvidaste la contraseña?',
    'register.title': 'Crear cuenta',
    'register.name': 'Nombre completo',
    'register.createAccount': 'Crear cuenta',
    'register.hasAccount': '¿Ya tienes cuenta?',
    'landing.hero': 'Captura e inspecciona cada webhook',
    'landing.subtitle': 'Un receptor profesional para webhooks de Discord y genéricos. Logs en tiempo real, secretos seguros y un panel diseñado con precisión.',
    'landing.startFree': 'Empezar gratis',
    'landing.signIn': 'Iniciar sesión',
    'landing.goDashboard': 'Ir al Panel',
    'webhooks.templates.title': 'Plantillas Roblox',
    'webhooks.templates.playerJoin': 'Jugador Entra',
    'webhooks.templates.serverStats': 'Estadísticas',
    'webhooks.templates.errorLogger': 'Registro de Errores',
    'webhooks.templates.adminCommand': 'Comando Admin',
    'webhooks.templates.generate': 'Generar Script Lua',
    'webhooks.templates.copy': 'Copiar Script',
    'webhooks.templates.preview': 'Vista Previa',
  },
}

export type LangCode = 'en' | 'es'

let currentLang: LangCode = 'en'

export function setLang(lang: LangCode) {
  currentLang = lang
  if (typeof window !== 'undefined') {
    localStorage.setItem('webhookpulse-lang', lang)
    document.documentElement.setAttribute('lang', lang)
  }
}

export function getLang(): LangCode {
  if (typeof window !== 'undefined') {
    const stored = localStorage.getItem('webhookpulse-lang') as LangCode
    if (stored && translations[stored]) return stored
  }
  return currentLang
}

export function t(key: TranslationKey): string {
  const lang = getLang()
  return translations[lang]?.[key] || translations['en'][key] || key
}

// Initialize from localStorage on load
if (typeof window !== 'undefined') {
  const stored = localStorage.getItem('webhookpulse-lang') as LangCode
  if (stored && translations[stored]) {
    currentLang = stored
    document.documentElement.setAttribute('lang', stored)
  }
}
