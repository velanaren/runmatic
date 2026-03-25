import { NavLink, Outlet, useNavigate } from 'react-router-dom'
import { clearToken, logout } from '../api/client'

const navItems = [
  { to: '/', label: 'Dashboard', exact: true },
  { to: '/runbooks', label: 'Runbooks' },
  { to: '/services', label: 'Services' },
  { to: '/incidents', label: 'Incidents' },
  { to: '/action-items', label: 'Action Items' },
]

export function Layout() {
  const navigate = useNavigate()

  const handleLogout = async () => {
    try {
      await logout()
    } catch {
      clearToken()
    }
    navigate('/login')
  }

  return (
    <div className="min-h-screen flex flex-col bg-background">
      {/* Top nav */}
      <header className="border-b border-border bg-surface/50 backdrop-blur-sm sticky top-0 z-10">
        <div className="max-w-7xl mx-auto px-6 h-14 flex items-center justify-between">
          <div className="flex items-center gap-8">
            <span className="text-text-primary font-semibold tracking-tight">
              <span className="text-accent">Run</span>matic
            </span>
            <nav className="flex items-center gap-1">
              {navItems.map((item) => (
                <NavLink
                  key={item.to}
                  to={item.to}
                  end={item.exact}
                  className={({ isActive }) =>
                    `px-3 py-1.5 text-sm rounded-md transition-colors duration-100 ${
                      isActive
                        ? 'text-text-primary bg-border'
                        : 'text-text-secondary hover:text-text-primary hover:bg-surface'
                    }`
                  }
                >
                  {item.label}
                </NavLink>
              ))}
            </nav>
          </div>
          <button
            onClick={handleLogout}
            className="text-text-secondary hover:text-text-primary text-sm transition-colors duration-100"
          >
            Sign out
          </button>
        </div>
      </header>

      {/* Page content */}
      <main className="flex-1 max-w-7xl mx-auto w-full px-6 py-8">
        <Outlet />
      </main>
    </div>
  )
}
