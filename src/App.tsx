import { lazy, Suspense } from 'react'
import { Routes, Route, Navigate } from 'react-router-dom'
import { AuthProvider, useAuth } from './hooks/useAuth'
import { useTheme, setTheme } from './hooks/useTheme'
import Layout from './components/Layout'
import ErrorBoundary from './components/ErrorBoundary'
import ScrollToTop from './components/ScrollToTop'

// Lazy load non-critical routes for code splitting
const LandingPage = lazy(() => import('./pages/LandingPage'))
const LoginPage = lazy(() => import('./pages/LoginPage'))
const RegisterPage = lazy(() => import('./pages/RegisterPage'))
const ForgotPasswordPage = lazy(() => import('./pages/ForgotPasswordPage'))
const ResetPasswordPage = lazy(() => import('./pages/ResetPasswordPage'))
const DashboardPage = lazy(() => import('./pages/DashboardPage'))
const WebhookDetailPage = lazy(() => import('./pages/WebhookDetailPage'))
const SettingsPage = lazy(() => import('./pages/SettingsPage'))
const StatsPage = lazy(() => import('./pages/StatsPage'))

// Loading skeleton for lazy routes
function PageSkeleton() {
  return (
    <div className="min-h-screen flex items-center justify-center bg-background">
      <div className="w-8 h-8 border-2 border-accent/20 border-t-accent rounded-full animate-spin" />
    </div>
  )
}

function App() {
  return (
    <ErrorBoundary>
      <AuthProvider>
        <ThemeProvider>
          <AppRoutes />
        </ThemeProvider>
      </AuthProvider>
    </ErrorBoundary>
  )
}

function ThemeProvider({ children }: { children: React.ReactNode }) {
  const { theme } = useTheme()
  useEffect(() => {
    setTheme(theme)
  }, [theme])
  return <>{children}</>
}

function AppRoutes() {
  const { user, loading } = useAuth()
  if (loading) return <PageSkeleton />

  return (
    <Suspense fallback={<PageSkeleton />}>
      <ScrollToTop />
      <Routes>
        <Route path="/" element={<LandingPage />} />
        <Route path="/login" element={user ? <Navigate to="/dashboard" /> : <LoginPage />} />
        <Route path="/register" element={user ? <Navigate to="/dashboard" /> : <RegisterPage />} />
        <Route path="/forgot-password" element={user ? <Navigate to="/dashboard" /> : <ForgotPasswordPage />} />
        <Route path="/reset-password" element={user ? <Navigate to="/dashboard" /> : <ResetPasswordPage />} />
        <Route element={<Layout />}>
          <Route path="/dashboard" element={user ? <DashboardPage /> : <Navigate to="/login" />} />
          <Route path="/dashboard/webhooks/:id" element={user ? <WebhookDetailPage /> : <Navigate to="/login" />} />
          <Route path="/dashboard/stats" element={user ? <StatsPage /> : <Navigate to="/login" />} />
          <Route path="/dashboard/settings" element={user ? <SettingsPage /> : <Navigate to="/login" />} />
        </Route>
      </Routes>
    </Suspense>
  )
}

export default App
