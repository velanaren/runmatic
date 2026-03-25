import { useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import { getDashboardStats, listIncidents, listRunbooks } from '../api/client'
import { StalenessIndicator } from '../components/StalenessIndicator'
import type { DashboardStats, Incident, Runbook } from '../types'

function StatCard({
  label,
  value,
  sub,
  accent,
}: {
  label: string
  value: number | string
  sub?: string
  accent?: string
}) {
  return (
    <div className="stat-card">
      <span className="text-text-secondary text-xs font-medium uppercase tracking-wider">
        {label}
      </span>
      <span className={`text-3xl font-semibold ${accent ?? 'text-text-primary'}`}>{value}</span>
      {sub && <span className="text-text-secondary text-xs">{sub}</span>}
    </div>
  )
}

export function Dashboard() {
  const [stats, setStats] = useState<DashboardStats | null>(null)
  const [recentRunbooks, setRecentRunbooks] = useState<Runbook[]>([])
  const [openIncidents, setOpenIncidents] = useState<Incident[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    const load = async () => {
      try {
        const [s, rbs, incs] = await Promise.all([
          getDashboardStats(),
          listRunbooks(),
          listIncidents(),
        ])
        setStats(s)
        setRecentRunbooks(rbs.slice(0, 5))
        setOpenIncidents(incs.filter((i) => !i.resolved_at).slice(0, 5))
      } catch {
        setError('Failed to load dashboard data')
      } finally {
        setLoading(false)
      }
    }
    load()
  }, [])

  if (loading) {
    return <div className="text-text-secondary text-sm">Loading…</div>
  }

  if (error) {
    return <div className="text-danger text-sm">{error}</div>
  }

  return (
    <div className="flex flex-col gap-8">
      <div className="flex items-center justify-between">
        <h1 className="page-title">Dashboard</h1>
        <Link to="/runbooks/new" className="btn-primary">
          + New Runbook
        </Link>
      </div>

      {/* Stat grid */}
      {stats && (
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
          <StatCard label="Total Runbooks" value={stats.runbook_total} />
          <StatCard
            label="Stale"
            value={stats.stale_count}
            sub={`${stats.warning_count} warning`}
            accent={stats.stale_count > 0 ? 'text-danger' : 'text-text-primary'}
          />
          <StatCard
            label="Needs Review"
            value={stats.needs_review_count}
            accent={stats.needs_review_count > 0 ? 'text-warning' : 'text-text-primary'}
          />
          <StatCard label="Open Incidents" value={stats.open_incidents} accent={stats.open_incidents > 0 ? 'text-danger' : 'text-text-primary'} />
        </div>
      )}

      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        {/* Stalest runbooks */}
        <div className="card">
          <div className="flex items-center justify-between mb-4">
            <h2 className="text-sm font-semibold text-text-primary">Most Stale Runbooks</h2>
            <Link to="/runbooks" className="text-accent text-xs hover:underline">
              View all
            </Link>
          </div>
          {recentRunbooks.length === 0 ? (
            <p className="text-text-secondary text-sm">No runbooks yet</p>
          ) : (
            <div className="flex flex-col divide-y divide-border">
              {recentRunbooks.map((rb) => (
                <div key={rb.id} className="flex items-center justify-between py-3 first:pt-0 last:pb-0">
                  <div className="flex flex-col gap-0.5 min-w-0">
                    <Link
                      to={`/runbooks/${rb.id}`}
                      className="text-sm text-text-primary hover:text-accent truncate"
                    >
                      {rb.title}
                    </Link>
                    <span className="text-xs text-text-secondary">{rb.service_name}</span>
                  </div>
                  <StalenessIndicator
                    status={rb.status}
                    staleness_days={rb.staleness_days}
                    showDays
                  />
                </div>
              ))}
            </div>
          )}
        </div>

        {/* Open incidents */}
        <div className="card">
          <div className="flex items-center justify-between mb-4">
            <h2 className="text-sm font-semibold text-text-primary">Open Incidents</h2>
            <Link to="/incidents" className="text-accent text-xs hover:underline">
              View all
            </Link>
          </div>
          {openIncidents.length === 0 ? (
            <p className="text-text-secondary text-sm">No open incidents</p>
          ) : (
            <div className="flex flex-col divide-y divide-border">
              {openIncidents.map((inc) => (
                <div key={inc.id} className="flex items-center justify-between py-3 first:pt-0 last:pb-0">
                  <div className="flex flex-col gap-0.5 min-w-0">
                    <span className="text-sm text-text-primary truncate">{inc.title}</span>
                    <span className="text-xs text-text-secondary">{inc.service_name}</span>
                  </div>
                  <span
                    className={`badge text-xs font-medium uppercase ${
                      inc.severity === 'p1'
                        ? 'bg-danger/10 text-danger'
                        : inc.severity === 'p2'
                          ? 'bg-warning/10 text-warning'
                          : 'bg-border text-text-secondary'
                    }`}
                  >
                    {inc.severity}
                  </span>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>
    </div>
  )
}
