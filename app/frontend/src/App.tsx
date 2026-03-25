import { Navigate, Route, Routes } from 'react-router-dom'
import { hasToken } from './api/client'
import { Layout } from './components/Layout'
import { ActionItems } from './pages/ActionItems'
import { Dashboard } from './pages/Dashboard'
import { Incidents } from './pages/Incidents'
import { Login } from './pages/Login'
import { RunbookDetail } from './pages/RunbookDetail'
import { RunbookList } from './pages/RunbookList'
import { Services } from './pages/Services'

function RequireAuth({ children }: { children: React.ReactNode }) {
  if (!hasToken()) {
    return <Navigate to="/login" replace />
  }
  return <>{children}</>
}

export function App() {
  return (
    <Routes>
      <Route path="/login" element={<Login />} />
      <Route
        path="/"
        element={
          <RequireAuth>
            <Layout />
          </RequireAuth>
        }
      >
        <Route index element={<Dashboard />} />
        <Route path="runbooks" element={<RunbookList />} />
        <Route path="runbooks/:id" element={<RunbookDetail />} />
        <Route path="services" element={<Services />} />
        <Route path="incidents" element={<Incidents />} />
        <Route path="action-items" element={<ActionItems />} />
        <Route path="*" element={<Navigate to="/" replace />} />
      </Route>
    </Routes>
  )
}
