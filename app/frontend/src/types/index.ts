export type RunbookStatus = 'fresh' | 'warning' | 'stale'
export type IncidentSeverity = 'p1' | 'p2' | 'p3' | 'p4'
export type ActionItemStatus = 'open' | 'in_progress' | 'done'

export interface Service {
  id: number
  name: string
  description: string | null
  owner_team: string | null
  created_at: string
  runbook_count?: number
  stale_count?: number
}

export interface RunbookStep {
  id: number
  runbook_id: number
  order: number
  description: string
  completed_at: string | null
}

export interface Runbook {
  id: number
  title: string
  content_md: string | null
  service_id: number
  service_name: string | null
  last_verified_at: string | null
  staleness_days: number
  status: RunbookStatus
  needs_review: boolean
  created_at: string
  updated_at: string
  steps?: RunbookStep[]
}

export interface Incident {
  id: number
  title: string
  severity: IncidentSeverity
  started_at: string
  resolved_at: string | null
  service_id: number
  service_name: string | null
  linked_runbooks?: IncidentRunbook[]
}

export interface IncidentRunbook {
  runbook_id: number
  runbook_title: string | null
  was_accurate: boolean | null
}

export interface ActionItem {
  id: number
  description: string
  status: ActionItemStatus
  incident_id: number | null
  runbook_id: number | null
  due_date: string | null
  created_at: string
}

export interface DashboardStats {
  runbook_total: number
  fresh_count: number
  warning_count: number
  stale_count: number
  needs_review_count: number
  open_incidents: number
  open_action_items: number
  services_total: number
}

export interface TokenResponse {
  access_token: string
  token_type: string
}
