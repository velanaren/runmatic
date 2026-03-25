import axios, { AxiosInstance, AxiosResponse } from 'axios'
import type {
  ActionItem,
  ActionItemStatus,
  DashboardStats,
  Incident,
  IncidentSeverity,
  Runbook,
  RunbookStatus,
  Service,
  TokenResponse,
} from '../types'

// Token stored in memory — not localStorage — for security
let _token: string | null = null

export function setToken(token: string): void {
  _token = token
}

export function clearToken(): void {
  _token = null
}

export function hasToken(): boolean {
  return _token !== null
}

const api: AxiosInstance = axios.create({
  baseURL: '/api',
  timeout: 10000,
  headers: { 'Content-Type': 'application/json' },
})

api.interceptors.request.use((config) => {
  if (_token) {
    config.headers.Authorization = `Bearer ${_token}`
  }
  return config
})

api.interceptors.response.use(
  (response) => response,
  (error) => {
    if (error.response?.status === 401) {
      clearToken()
      window.location.href = '/login'
    }
    return Promise.reject(error)
  },
)

// ---------------------------------------------------------------------------
// Auth
// ---------------------------------------------------------------------------

export async function login(email: string, password: string): Promise<TokenResponse> {
  const res: AxiosResponse<TokenResponse> = await api.post('/auth/login', { email, password })
  return res.data
}

export async function logout(): Promise<void> {
  await api.post('/auth/logout')
  clearToken()
}

// ---------------------------------------------------------------------------
// Dashboard
// ---------------------------------------------------------------------------

export async function getDashboardStats(): Promise<DashboardStats> {
  const res: AxiosResponse<DashboardStats> = await api.get('/dashboard')
  return res.data
}

// ---------------------------------------------------------------------------
// Services
// ---------------------------------------------------------------------------

export async function listServices(): Promise<Service[]> {
  const res: AxiosResponse<Service[]> = await api.get('/services')
  return res.data
}

export async function createService(data: {
  name: string
  description?: string
  owner_team?: string
}): Promise<Service> {
  const res: AxiosResponse<Service> = await api.post('/services', data)
  return res.data
}

export async function getService(id: number): Promise<Service> {
  const res: AxiosResponse<Service> = await api.get(`/services/${id}`)
  return res.data
}

// ---------------------------------------------------------------------------
// Runbooks
// ---------------------------------------------------------------------------

export async function listRunbooks(params?: {
  service_id?: number
  status?: RunbookStatus
  needs_review?: boolean
  search?: string
}): Promise<Runbook[]> {
  const res: AxiosResponse<Runbook[]> = await api.get('/runbooks', { params })
  return res.data
}

export async function getRunbook(id: number): Promise<Runbook> {
  const res: AxiosResponse<Runbook> = await api.get(`/runbooks/${id}`)
  return res.data
}

export async function createRunbook(data: {
  title: string
  content_md?: string
  service_id: number
  steps?: { order: number; description: string }[]
}): Promise<Runbook> {
  const res: AxiosResponse<Runbook> = await api.post('/runbooks', data)
  return res.data
}

export async function updateRunbook(
  id: number,
  data: { title?: string; content_md?: string },
): Promise<Runbook> {
  const res: AxiosResponse<Runbook> = await api.put(`/runbooks/${id}`, data)
  return res.data
}

export async function verifyRunbook(id: number): Promise<Runbook> {
  const res: AxiosResponse<Runbook> = await api.post(`/runbooks/${id}/verify`)
  return res.data
}

// ---------------------------------------------------------------------------
// Incidents
// ---------------------------------------------------------------------------

export async function listIncidents(): Promise<Incident[]> {
  const res: AxiosResponse<Incident[]> = await api.get('/incidents')
  return res.data
}

export async function createIncident(data: {
  title: string
  severity: IncidentSeverity
  started_at: string
  service_id: number
}): Promise<Incident> {
  const res: AxiosResponse<Incident> = await api.post('/incidents', data)
  return res.data
}

export async function resolveIncident(id: number): Promise<Incident> {
  const res: AxiosResponse<Incident> = await api.put(`/incidents/${id}/resolve`, {})
  return res.data
}

export async function linkRunbookToIncident(
  incidentId: number,
  runbookId: number,
  wasAccurate?: boolean,
): Promise<Incident> {
  const res: AxiosResponse<Incident> = await api.post(`/incidents/${incidentId}/runbooks`, {
    runbook_id: runbookId,
    was_accurate: wasAccurate,
  })
  return res.data
}

// ---------------------------------------------------------------------------
// Action Items
// ---------------------------------------------------------------------------

export async function listActionItems(params?: {
  status?: ActionItemStatus
  incident_id?: number
  runbook_id?: number
}): Promise<ActionItem[]> {
  const res: AxiosResponse<ActionItem[]> = await api.get('/action-items', { params })
  return res.data
}

export async function createActionItem(data: {
  description: string
  incident_id?: number
  runbook_id?: number
  due_date?: string
}): Promise<ActionItem> {
  const res: AxiosResponse<ActionItem> = await api.post('/action-items', data)
  return res.data
}

export async function updateActionItem(
  id: number,
  data: { status?: ActionItemStatus; description?: string; due_date?: string },
): Promise<ActionItem> {
  const res: AxiosResponse<ActionItem> = await api.put(`/action-items/${id}`, data)
  return res.data
}
