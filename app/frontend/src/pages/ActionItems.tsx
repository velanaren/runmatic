import { useEffect, useState } from 'react'
import { listActionItems, updateActionItem } from '../api/client'
import type { ActionItem, ActionItemStatus } from '../types'

const STATUS_CONFIG: Record<ActionItemStatus, { label: string; badge: string }> = {
  open: { label: 'Open', badge: 'bg-danger/10 text-danger' },
  in_progress: { label: 'In Progress', badge: 'bg-warning/10 text-warning' },
  done: { label: 'Done', badge: 'bg-success/10 text-success' },
}

const NEXT_STATUS: Record<ActionItemStatus, ActionItemStatus> = {
  open: 'in_progress',
  in_progress: 'done',
  done: 'open',
}

function formatDueDate(iso: string | null) {
  if (!iso) return null
  const date = new Date(iso)
  const now = new Date()
  const overdue = date < now
  const label = date.toLocaleDateString('en-US', { month: 'short', day: 'numeric' })
  return { label, overdue }
}

export function ActionItems() {
  const [items, setItems] = useState<ActionItem[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [filter, setFilter] = useState<ActionItemStatus | ''>('')

  useEffect(() => {
    const load = async () => {
      try {
        const data = await listActionItems()
        setItems(data)
      } catch {
        setError('Failed to load action items')
      } finally {
        setLoading(false)
      }
    }
    load()
  }, [])

  const handleAdvanceStatus = async (item: ActionItem) => {
    const nextStatus = NEXT_STATUS[item.status]
    try {
      const updated = await updateActionItem(item.id, { status: nextStatus })
      setItems((prev) => prev.map((i) => (i.id === item.id ? updated : i)))
    } catch {
      setError('Failed to update action item')
    }
  }

  const filtered = filter ? items.filter((i) => i.status === filter) : items

  if (loading) return <div className="text-text-secondary text-sm">Loading…</div>
  if (error) return <div className="text-danger text-sm">{error}</div>

  return (
    <div className="flex flex-col gap-6">
      <div className="flex items-center justify-between">
        <h1 className="page-title">Action Items</h1>
        <div className="flex gap-2">
          {(['', 'open', 'in_progress', 'done'] as const).map((s) => (
            <button
              key={s}
              onClick={() => setFilter(s as ActionItemStatus | '')}
              className={`text-xs px-3 py-1.5 rounded-md transition-colors ${
                filter === s
                  ? 'bg-accent text-white'
                  : 'bg-surface border border-border text-text-secondary hover:text-text-primary'
              }`}
            >
              {s === '' ? 'All' : STATUS_CONFIG[s as ActionItemStatus].label}
            </button>
          ))}
        </div>
      </div>

      <div className="card p-0 overflow-hidden">
        <table className="w-full text-sm">
          <thead>
            <tr className="border-b border-border">
              <th className="text-left text-text-secondary font-medium px-4 py-3">Description</th>
              <th className="text-left text-text-secondary font-medium px-4 py-3">Status</th>
              <th className="text-left text-text-secondary font-medium px-4 py-3">Due</th>
              <th className="px-4 py-3" />
            </tr>
          </thead>
          <tbody>
            {filtered.length === 0 ? (
              <tr>
                <td colSpan={4} className="px-4 py-8 text-center text-text-secondary">
                  No action items
                </td>
              </tr>
            ) : (
              filtered.map((item) => {
                const due = formatDueDate(item.due_date)
                const cfg = STATUS_CONFIG[item.status]
                return (
                  <tr key={item.id} className="table-row">
                    <td className="px-4 py-3 text-text-primary max-w-sm">
                      <span className={item.status === 'done' ? 'line-through text-text-secondary' : ''}>
                        {item.description}
                      </span>
                    </td>
                    <td className="px-4 py-3">
                      <span className={`badge ${cfg.badge}`}>{cfg.label}</span>
                    </td>
                    <td className="px-4 py-3">
                      {due ? (
                        <span
                          className={`text-xs ${due.overdue && item.status !== 'done' ? 'text-danger' : 'text-text-secondary'}`}
                        >
                          {due.label}
                          {due.overdue && item.status !== 'done' && ' · overdue'}
                        </span>
                      ) : (
                        <span className="text-text-secondary text-xs">—</span>
                      )}
                    </td>
                    <td className="px-4 py-3 text-right">
                      {item.status !== 'done' && (
                        <button
                          onClick={() => handleAdvanceStatus(item)}
                          className="text-xs text-accent hover:underline"
                        >
                          {item.status === 'open' ? 'Start' : 'Done'}
                        </button>
                      )}
                    </td>
                  </tr>
                )
              })
            )}
          </tbody>
        </table>
      </div>
    </div>
  )
}
