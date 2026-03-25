import { useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import { listRunbooks, listServices } from '../api/client'
import { StalenessIndicator } from '../components/StalenessIndicator'
import type { Runbook, RunbookStatus, Service } from '../types'

const STATUS_OPTIONS: { value: RunbookStatus | ''; label: string }[] = [
  { value: '', label: 'All statuses' },
  { value: 'fresh', label: 'Fresh' },
  { value: 'warning', label: 'Warning' },
  { value: 'stale', label: 'Stale' },
]

export function RunbookList() {
  const [runbooks, setRunbooks] = useState<Runbook[]>([])
  const [services, setServices] = useState<Service[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [search, setSearch] = useState('')
  const [serviceFilter, setServiceFilter] = useState<string>('')
  const [statusFilter, setStatusFilter] = useState<RunbookStatus | ''>('')

  useEffect(() => {
    const load = async () => {
      try {
        const [rbs, svcs] = await Promise.all([listRunbooks(), listServices()])
        setRunbooks(rbs)
        setServices(svcs)
      } catch {
        setError('Failed to load runbooks')
      } finally {
        setLoading(false)
      }
    }
    load()
  }, [])

  const filtered = runbooks.filter((rb) => {
    if (search && !rb.title.toLowerCase().includes(search.toLowerCase())) return false
    if (serviceFilter && rb.service_id !== Number(serviceFilter)) return false
    if (statusFilter && rb.status !== statusFilter) return false
    return true
  })

  if (loading) return <div className="text-text-secondary text-sm">Loading…</div>
  if (error) return <div className="text-danger text-sm">{error}</div>

  return (
    <div className="flex flex-col gap-6">
      <div className="flex items-center justify-between">
        <h1 className="page-title">Runbooks</h1>
        <Link to="/runbooks/new" className="btn-primary">
          + New Runbook
        </Link>
      </div>

      {/* Filters */}
      <div className="flex flex-wrap gap-3">
        <input
          type="text"
          className="input max-w-xs"
          placeholder="Search runbooks…"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
        />
        <select
          className="input max-w-[180px]"
          value={serviceFilter}
          onChange={(e) => setServiceFilter(e.target.value)}
        >
          <option value="">All services</option>
          {services.map((s) => (
            <option key={s.id} value={s.id}>
              {s.name}
            </option>
          ))}
        </select>
        <select
          className="input max-w-[160px]"
          value={statusFilter}
          onChange={(e) => setStatusFilter(e.target.value as RunbookStatus | '')}
        >
          {STATUS_OPTIONS.map((o) => (
            <option key={o.value} value={o.value}>
              {o.label}
            </option>
          ))}
        </select>
      </div>

      {/* Table */}
      <div className="card p-0 overflow-hidden">
        <table className="w-full text-sm">
          <thead>
            <tr className="border-b border-border">
              <th className="text-left text-text-secondary font-medium px-4 py-3">Title</th>
              <th className="text-left text-text-secondary font-medium px-4 py-3">Service</th>
              <th className="text-left text-text-secondary font-medium px-4 py-3">Staleness</th>
              <th className="text-left text-text-secondary font-medium px-4 py-3">Review</th>
            </tr>
          </thead>
          <tbody>
            {filtered.length === 0 ? (
              <tr>
                <td colSpan={4} className="px-4 py-8 text-center text-text-secondary">
                  No runbooks found
                </td>
              </tr>
            ) : (
              filtered.map((rb) => (
                <tr key={rb.id} className="table-row">
                  <td className="px-4 py-3">
                    <Link
                      to={`/runbooks/${rb.id}`}
                      className="text-text-primary hover:text-accent transition-colors"
                    >
                      {rb.title}
                    </Link>
                  </td>
                  <td className="px-4 py-3 text-text-secondary">{rb.service_name ?? '—'}</td>
                  <td className="px-4 py-3">
                    <StalenessIndicator status={rb.status} staleness_days={rb.staleness_days} />
                  </td>
                  <td className="px-4 py-3">
                    {rb.needs_review ? (
                      <span className="badge bg-warning/10 text-warning">Needs review</span>
                    ) : (
                      <span className="text-text-secondary">—</span>
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
