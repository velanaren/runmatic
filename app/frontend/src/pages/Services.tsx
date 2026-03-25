import { useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import { listServices } from '../api/client'
import type { Service } from '../types'

export function Services() {
  const [services, setServices] = useState<Service[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    const load = async () => {
      try {
        const data = await listServices()
        setServices(data)
      } catch {
        setError('Failed to load services')
      } finally {
        setLoading(false)
      }
    }
    load()
  }, [])

  if (loading) return <div className="text-text-secondary text-sm">Loading…</div>
  if (error) return <div className="text-danger text-sm">{error}</div>

  return (
    <div className="flex flex-col gap-6">
      <h1 className="page-title">Services</h1>

      <div className="card p-0 overflow-hidden">
        <table className="w-full text-sm">
          <thead>
            <tr className="border-b border-border">
              <th className="text-left text-text-secondary font-medium px-4 py-3">Service</th>
              <th className="text-left text-text-secondary font-medium px-4 py-3">Team</th>
              <th className="text-left text-text-secondary font-medium px-4 py-3">Runbooks</th>
              <th className="text-left text-text-secondary font-medium px-4 py-3">Stale</th>
            </tr>
          </thead>
          <tbody>
            {services.length === 0 ? (
              <tr>
                <td colSpan={4} className="px-4 py-8 text-center text-text-secondary">
                  No services found
                </td>
              </tr>
            ) : (
              services.map((svc) => (
                <tr key={svc.id} className="table-row">
                  <td className="px-4 py-3">
                    <div className="flex flex-col gap-0.5">
                      <span className="text-text-primary font-medium">{svc.name}</span>
                      {svc.description && (
                        <span className="text-text-secondary text-xs">{svc.description}</span>
                      )}
                    </div>
                  </td>
                  <td className="px-4 py-3 text-text-secondary">{svc.owner_team ?? '—'}</td>
                  <td className="px-4 py-3">
                    <Link
                      to={`/runbooks?service_id=${svc.id}`}
                      className="text-accent hover:underline"
                    >
                      {svc.runbook_count ?? 0}
                    </Link>
                  </td>
                  <td className="px-4 py-3">
                    {(svc.stale_count ?? 0) > 0 ? (
                      <span className="badge bg-danger/10 text-danger">{svc.stale_count}</span>
                    ) : (
                      <span className="text-text-secondary">0</span>
                    )}
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>
    </div>
  )
}
