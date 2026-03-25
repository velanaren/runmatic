import type { RunbookStatus } from '../types'

interface StalenessIndicatorProps {
  status: RunbookStatus
  staleness_days: number
  showDays?: boolean
}

const statusConfig: Record<RunbookStatus, { dot: string; text: string; badge: string }> = {
  fresh: {
    dot: 'bg-success',
    text: 'text-success',
    badge: 'bg-success/10 text-success',
  },
  warning: {
    dot: 'bg-warning',
    text: 'text-warning',
    badge: 'bg-warning/10 text-warning',
  },
  stale: {
    dot: 'bg-danger',
    text: 'text-danger',
    badge: 'bg-danger/10 text-danger',
  },
}

export function StalenessIndicator({
  status,
  staleness_days,
  showDays = true,
}: StalenessIndicatorProps) {
  const config = statusConfig[status]

  const label =
    staleness_days === 0
      ? 'Today'
      : staleness_days === 1
        ? '1 day ago'
        : `${staleness_days}d ago`

  return (
    <span className={`badge ${config.badge}`}>
      <span className={`w-1.5 h-1.5 rounded-full ${config.dot} flex-shrink-0`} />
      {showDays ? label : status}
    </span>
  )
}
