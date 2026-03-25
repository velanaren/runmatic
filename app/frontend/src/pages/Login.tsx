import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { login, setToken } from '../api/client'

export function Login() {
  const [email, setEmail] = useState('demo@runmatic.dev')
  const [password, setPassword] = useState('demo1234')
  const [error, setError] = useState<string | null>(null)
  const [loading, setLoading] = useState(false)
  const navigate = useNavigate()

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setError(null)
    setLoading(true)

    try {
      const data = await login(email, password)
      setToken(data.access_token)
      navigate('/')
    } catch {
      setError('Invalid email or password')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="min-h-screen bg-background flex items-center justify-center px-4">
      <div className="w-full max-w-sm">
        <div className="mb-8 text-center">
          <h1 className="text-2xl font-semibold text-text-primary">
            <span className="text-accent">Run</span>matic
          </h1>
          <p className="text-text-secondary text-sm mt-2">Living runbooks for SRE teams</p>
        </div>

        <form onSubmit={handleSubmit} className="card flex flex-col gap-4">
          <div>
            <label className="label" htmlFor="email">
              Email
            </label>
            <input
              id="email"
              type="email"
              className="input"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              required
              autoComplete="email"
            />
          </div>
          <div>
            <label className="label" htmlFor="password">
              Password
            </label>
            <input
              id="password"
              type="password"
              className="input"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              required
              autoComplete="current-password"
            />
          </div>

          {error && (
            <p className="text-danger text-sm text-center">{error}</p>
          )}

          <button type="submit" className="btn-primary w-full mt-2" disabled={loading}>
            {loading ? 'Signing in…' : 'Sign in'}
          </button>
        </form>

        <p className="text-center text-text-secondary text-xs mt-6">
          Demo credentials pre-filled above
        </p>
      </div>
    </div>
  )
}
