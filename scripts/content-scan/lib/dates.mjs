export function parseDeadline(raw) {
  const s = String(raw || '').trim();
  if (!s || s.toLowerCase() === 'null') return null;
  const m = s.match(/^(\d{4})-(\d{2})-(\d{2})/);
  if (!m) return null;
  const d = Date.parse(`${m[1]}-${m[2]}-${m[3]}T00:00:00Z`);
  if (!Number.isFinite(d)) return null;
  return `${m[1]}-${m[2]}-${m[3]}`;
}

export function daysLeft(deadline, now = new Date()) {
  const day = parseDeadline(deadline);
  if (!day) return null;
  const end = Date.parse(`${day}T00:00:00Z`);
  const start = Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate());
  return Math.round((end - start) / 86400000);
}

export function deadlineFlags(deadline, now = new Date()) {
  const left = daysLeft(deadline, now);
  if (left == null) {
    return { days_left: null, expired: false, urgent: false, status: null };
  }
  if (left < 0) {
    return { days_left: left, expired: true, urgent: false, status: 'expired' };
  }
  return {
    days_left: left,
    expired: false,
    urgent: left <= 7,
    status: null,
  };
}
