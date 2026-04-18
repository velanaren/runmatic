import { useEffect, useState } from 'react'
import ReactMarkdown from 'react-markdown'
import { useNavigate, useParams } from 'react-router-dom'
import { createRunbook, getRunbook, listServices, verifyRunbook } from '../api/client'
import { StalenessIndicator } from '../components/StalenessIndicator'
import type { Runbook, Service } from '../types'

export function RunbookDetail() {
  const { id } = useParams<{ id: string }>()
  const navigate = useNavigate()
  const [runbook, setRunbook] = useState<Runbook | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [verifying, setVerifying] = useState(false)
  const [activeTab, setActiveTab] = useState<'content' | 'steps' | 'history'>('content')
  const [completedSteps, setCompletedSteps] = useState<Set<number>>(new Set())

  // New runbook form state
  const [services, setServices] = useState<Service[]>([])
  const [formData, setFormData] = useState({ title: '', content_md: '', service_id: '' })
  const [creating, setCreating] = useState(false)

  const isNew = id === 'new'

  useEffect(() => {
    if (!id) return
    if (isNew) {
      const loadServices = async () => {
        try {
          const svcs = await listServices()
          setServices(svcs)
          if (svcs.length > 0) setFormData((prev) => ({ ...prev, service_id: String(svcs[0].id) }))
        } catch {
          setError('Failed to load services')
        } finally {
          setLoading(false)
        }
      }
      loadServices()
      return
    }
    const load = async () => {
      try {
        const rb = await getRunbook(Number(id))
        setRunbook(rb)
      } catch {
        setError('Runbook not found')
      } finally {
        setLoading(false)
      }
    }
    load()
  }, [id, isNew])

  const handleVerify = async () => {
    if (!runbook) return
    setVerifying(true)
    try {
      const updated = await verifyRunbook(runbook.id)
      setRunbook(updated)
    } catch {
      setError('Failed to verify runbook')
    } finally {
      setVerifying(false)
    }
  }

  const toggleStep = (stepId: number) => {
    setCompletedSteps((prev) => {
      const next = new Set(prev)
      if (next.has(stepId)) {
        next.delete(stepId)
      } else {
        next.add(stepId)
      }
      return next
    })
  }

  const handleCreate = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!formData.title || !formData.service_id) return
    setCreating(true)
    setError(null)
    try {
      const newRunbook = await createRunbook({
        title: formData.title,
        content_md: formData.content_md || undefined,
        service_id: Number(formData.service_id),
      })
      navigate(`/runbooks/${newRunbook.id}`)
    } catch {
      setError('Failed to create runbook')
    } finally {
      setCreating(false)
    }
  }

  if (loading) return <div className="text-text-secondary text-sm">Loading…</div>

  if (isNew) {
    return (
      <div className="flex flex-col gap-6 max-w-2xl">
        <div className="flex items-center gap-2">
          <button
            onClick={() => navigate('/runbooks')}
            className="text-text-secondary hover:text-text-primary text-sm transition-colors"
          >
            ← Runbooks
          </button>
        </div>
        <h1 className="page-title">New Runbook</h1>
        {error && <div className="text-danger text-sm">{error}</div>}
        <form onSubmit={handleCreate} className="card flex flex-col gap-4">
          <div className="flex flex-col gap-2">
            <label htmlFor="title" className="text-sm font-medium text-text-primary">
              Title
            </label>
            <input
              id="title"
              type="text"
              className="input"
              placeholder="e.g., API Health Check Failure"
              value={formData.title}
              onChange={(e) => setFormData({ ...formData, title: e.target.value })}
              required
            />
          </div>
          <div className="flex flex-col gap-2">
            <label htmlFor="service" className="text-sm font-medium text-text-primary">
              Service
            </label>
            <select
              id="service"
              className="input"
              value={formData.service_id}
              onChange={(e) => setFormData({ ...formData, service_id: e.target.value })}
              required
            >
              {services.map((s) => (
                <option key={s.id} value={s.id}>
                  {s.name}
                </option>
              ))}
            </select>
          </div>
          <div className="flex flex-col gap-2">
            <label htmlFor="content" className="text-sm font-medium text-text-primary">
              Content (Markdown)
            </label>
            <textarea
              id="content"
              className="input font-mono text-sm"
              rows={12}
              placeholder="# Steps&#10;1. Check status&#10;2. Investigate logs&#10;3. Take action"
              value={formData.content_md}
              onChange={(e) => setFormData({ ...formData, content_md: e.target.value })}
            />
          </div>
          <div className="flex gap-3">
            <button type="submit" className="btn-primary" disabled={creating}>
              {creating ? 'Creating…' : 'Create Runbook'}
            </button>
            <button
              type="button"
              onClick={() => navigate('/runbooks')}
              className="px-4 py-2 text-sm text-text-secondary hover:text-text-primary transition-colors"
            >
              Cancel
            </button>
          </div>
        </form>
      </div>
    )
  }

  if (error || !runbook) return <div className="text-danger text-sm">{error ?? 'Not found'}</div>

  return (
    <div className="flex flex-col gap-6 max-w-4xl">
      {/* Header */}
      <div className="flex items-start justify-between gap-4">
        <div className="flex flex-col gap-2">
          <div className="flex items-center gap-2">
            <button
              onClick={() => navigate('/runbooks')}
              className="text-text-secondary hover:text-text-primary text-sm transition-colors"
            >
              ← Runbooks
            </button>
          </div>
          <h1 className="page-title">{runbook.title}</h1>
          <div className="flex items-center gap-3 text-sm text-text-secondary">
            <span>{runbook.service_name}</span>
            <span>·</span>
            <StalenessIndicator status={runbook.status} staleness_days={runbook.staleness_days} />
            {runbook.needs_review && (
              <>
                <span>·</span>
                <span className="badge bg-warning/10 text-warning">Needs review</span>
              </>
            )}
          </div>
        </div>
        <button
          onClick={handleVerify}
          disabled={verifying}
          className="btn-primary flex-shrink-0"
        >
          {verifying ? 'Verifying…' : 'Mark as Verified'}
        </button>
      </div>

      {/* Tabs */}
      <div className="border-b border-border flex gap-1">
        {(['content', 'steps', 'history'] as const).map((tab) => (
          <button
            key={tab}
            onClick={() => setActiveTab(tab)}
            className={`px-4 py-2 text-sm capitalize transition-colors border-b-2 -mb-px ${
              activeTab === tab
                ? 'border-accent text-text-primary'
                : 'border-transparent text-text-secondary hover:text-text-primary'
            }`}
          >
            {tab}
            {tab === 'steps' && runbook.steps && ` (${runbook.steps.length})`}
          </button>
        ))}
      </div>

      {/* Content */}
      {activeTab === 'content' && (
        <div className="card prose prose-invert prose-sm max-w-none">
          {runbook.content_md ? (
            <ReactMarkdown>{runbook.content_md}</ReactMarkdown>
          ) : (
            <p className="text-text-secondary">No content yet.</p>
          )}
        </div>
      )}

      {activeTab === 'steps' && (
        <div className="card flex flex-col gap-3">
          {!runbook.steps || runbook.steps.length === 0 ? (
            <p className="text-text-secondary text-sm">No steps defined.</p>
          ) : (
            runbook.steps.map((step) => {
              const done = completedSteps.has(step.id)
              return (
                <div
                  key={step.id}
                  className={`flex items-start gap-3 p-3 rounded-md border transition-colors cursor-pointer ${
                    done ? 'border-success/30 bg-success/5' : 'border-border hover:border-border/70'
                  }`}
                  onClick={() => toggleStep(step.id)}
                >
                  <div
                    className={`w-5 h-5 rounded border flex-shrink-0 flex items-center justify-center mt-0.5 transition-colors ${
                      done ? 'bg-success border-success' : 'border-border'
                    }`}
                  >
                    {done && (
                      <svg className="w-3 h-3 text-white" fill="none" viewBox="0 0 12 12">
                        <path
                          d="M2 6l3 3 5-5"
                          stroke="currentColor"
                          strokeWidth="2"
                          strokeLinecap="round"
                          strokeLinejoin="round"
                        />
                      </svg>
                    )}
                  </div>
                  <div className="flex-1">
                    <span className="text-xs text-text-secondary font-medium mr-2">
                      {step.order}.
                    </span>
                    <span
                      className={`text-sm ${done ? 'line-through text-text-secondary' : 'text-text-primary'}`}
                    >
                      {step.description}
                    </span>
                  </div>
                </div>
              )
            })
          )}
        </div>
      )}

      {activeTab === 'history' && (
        <div className="card">
          <p className="text-text-secondary text-sm">
            Incident history for this runbook will appear here.
          </p>
        </div>
      )}
    </div>
  )
}
