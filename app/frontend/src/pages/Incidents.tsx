import { useEffect, useState } from 'react'
import { listIncidents, resolveIncident } from '../api/client'
import type { Incident } from '../types'

const SEVERITY_COLORS: Record<string, string> = {
  p1: 'bg-danger/10 text-danger',
  p2: 'bg-warning/10 text-warning',
  p3: 'bg-accent/10 text-accent',
  p4: 'bg-border text-text-secondary',
}

function formatDate(iso: string) {
  return new Date(iso).toLocaleDateString('en-US', {
    month: 'short',
    day: 'numeric',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  })
}

export function Incidents() {
  const [incidents, setIncidents] = useState<Incident[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    const load = async () => {
      try {
        const data = await listIncidents()
        setIncidents(data)
      } catch {
        setError('Failed to load incidents')
      } finally {
        setLoading(false)
      }
    }
    load()
  }, [])

  const handleResolve = async (id: number) => {
    try {
      const updated = await resolveIncident(id)
      setIncidents((prev) => prev.map((i) => (i.id === id ? updated : i)))
    } catch {
      setError('Failed to resolve incident')
    }
  }

  if (loading) return <div className="text-text-secondary text-sm">Loading…</div>
  if (error) return <div className="text-danger text-sm">{error}</div>

  return (
    <div className="flex flex-col gap-6">
      <h1 className="page-title">Incidents</h1>

      <div className="card p-0 overflow-hidden">
        <table className="w-full text-sm">
          <thead>
            <tr className="border-b border-border">
              <th className="text-left text-text-secondary font-medium px-4 py-3">Incident</th>
              <th className="text-left text-text-secondary font-medium px-4 py-3">Severity</th>
              <th className="text-left text-text-secondary font-medium px-4 py-3">Service</th>
              <th className="text-left text-text-secondary font-medium px-4 py-3">Started</th>
              <th className="text-left text-text-secondary font-medium px-4 py-3">Status</th>
              <th className="px-4 py-3" />
            </tr>
          </thead>
          <tbody>
            {incidents.length === 0 ? (
              <tr>
                <td colSpan={6} className="px-4 py-8 text-center text-text-secondary">
                  No incidents recorded
                </td>
              </tr>
            ) : (
              incidents.map((inc) => (
                <tr key={inc.id} className="table-row">
                  <td className="px-4 py-3 text-text-primary">{inc.title}</td>
                  <td className="px-4 py-3">
                    <span className={`badge uppercase font-medium ${SEVERITY_COLORS[inc.severity] ?? ''}`}>
                      {inc.severity}
                    </span>
                  </td>
                  <td className="px-4 py-3 text-text-secondary">{inc.service_name ?? '—'}</td>
                  <td className="px-4 py-3 text-text-secondary text-xs">
                    {formatDate(inc.started_at)}
                  </td>
                  <td className="px-4 py-3">
                    {inc.resolved_at ? (
                      <span className="badge bg-success/10 text-success">Resolved</span>
                    ) : (
                      <span className="badge bg-danger/10 text-danger">Open</span>
                    )}
                  </td>
                  <td className="px-4 py-3 text-right">
                    {!inc.resolved_at && (
                      <button
                        onClick={() => handleResolve(inc.id)}
                        className="text-xs text-text-secondary hover:text-text-primary transition-colors"
                      >
                        Resolve
                      </button>
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
