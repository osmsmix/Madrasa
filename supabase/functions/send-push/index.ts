// send-push: fan out a push notification when a grade, an absence/late, or an
// announcement is written. Wired via Supabase Database Webhooks (INSERT/UPDATE)
// on the `grades`, `attendance`, and `announcements` tables.
//
// Secrets required:
//   FCM_SERVICE_ACCOUNT  — the Firebase service-account JSON (as a string)
//   WEBHOOK_SECRET       — optional shared secret; if set, callers must send it
//                          in the `x-webhook-secret` header.
// SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY are injected automatically.
import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.7'

const admin = createClient(
  Deno.env.get('SUPABASE_URL') ?? '',
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
)

// ── FCM v1 auth ─────────────────────────────────────────────────────────────
function pemToBuffer(pem: string): ArrayBuffer {
  const b64 = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, '')
    .replace(/-----END PRIVATE KEY-----/, '')
    .replace(/\s+/g, '')
  const bin = atob(b64)
  const buf = new Uint8Array(bin.length)
  for (let i = 0; i < bin.length; i++) buf[i] = bin.charCodeAt(i)
  return buf.buffer
}

function b64url(input: string | ArrayBuffer): string {
  let str: string
  if (typeof input === 'string') {
    str = btoa(input)
  } else {
    str = btoa(String.fromCharCode(...new Uint8Array(input)))
  }
  return str.replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '')
}

let _token: { value: string; exp: number } | null = null

async function accessToken(sa: any): Promise<string> {
  const now = Math.floor(Date.now() / 1000)
  if (_token && _token.exp > now + 60) return _token.value
  const header = { alg: 'RS256', typ: 'JWT' }
  const claims = {
    iss: sa.client_email,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  }
  const unsigned =
    b64url(JSON.stringify(header)) + '.' + b64url(JSON.stringify(claims))
  const key = await crypto.subtle.importKey(
    'pkcs8',
    pemToBuffer(sa.private_key),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  )
  const sig = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    key,
    new TextEncoder().encode(unsigned),
  )
  const jwt = unsigned + '.' + b64url(sig)
  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body:
      'grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=' + jwt,
  })
  const json = await res.json()
  _token = { value: json.access_token, exp: now + 3500 }
  return json.access_token
}

async function sendToTokens(
  tokens: string[],
  title: string,
  body: string,
  data: Record<string, string> = {},
) {
  if (tokens.length === 0) return
  const sa = JSON.parse(Deno.env.get('FCM_SERVICE_ACCOUNT') ?? '{}')
  const token = await accessToken(sa)
  const url = `https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`
  await Promise.allSettled(
    tokens.map(async (t) => {
      const res = await fetch(url, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${token}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          message: { token: t, notification: { title, body }, data },
        }),
      })
      if (!res.ok) {
        const txt = await res.text()
        console.log('FCM error for token', t.slice(0, 12), res.status, txt)
        // Clean up tokens FCM says are gone.
        if (res.status === 404 || res.status === 400) {
          await admin.from('devices').delete().eq('fcm_token', t)
        }
      }
    }),
  )
}

// ── recipient helpers ───────────────────────────────────────────────────────
async function tokensForUserIds(ids: string[]): Promise<string[]> {
  if (ids.length === 0) return []
  const { data } = await admin
    .from('devices')
    .select('fcm_token')
    .in('user_id', ids)
  return (data ?? []).map((r: any) => r.fcm_token as string)
}

async function tokensForPhones(phones: string[]): Promise<string[]> {
  const clean = phones.filter((p) => p && p.length > 0)
  if (clean.length === 0) return []
  const { data } = await admin
    .from('profiles')
    .select('id')
    .in('phone', clean)
  const ids = (data ?? []).map((r: any) => r.id as string)
  return tokensForUserIds(ids)
}

// ── handlers per table ──────────────────────────────────────────────────────
async function onGrade(record: any) {
  const { data: student } = await admin
    .from('students')
    .select('full_name, parent_phone_1, parent_phone_2')
    .eq('id', record.student_id)
    .maybeSingle()
  if (!student) return
  const { data: a } = await admin
    .from('assessments')
    .select('title, class_subjects(subjects(name))')
    .eq('id', record.assessment_id)
    .maybeSingle()
  const subject = a?.class_subjects?.subjects?.name ?? ''
  const tokens = await tokensForPhones([
    student.parent_phone_1,
    student.parent_phone_2,
  ])
  await sendToTokens(
    tokens,
    'Nouvelle note',
    `${student.full_name} — ${subject}: ${record.value ?? ''}`,
    { type: 'grade' },
  )
}

async function onAttendance(record: any, oldRecord: any, isInsert: boolean) {
  const status = record.status as string
  if (status !== 'absent' && status !== 'late') return
  // Only notify on the first mark or an actual status change (not excuse edits).
  if (!isInsert && oldRecord?.status === status) return
  const { data: student } = await admin
    .from('students')
    .select('full_name, parent_phone_1, parent_phone_2')
    .eq('id', record.student_id)
    .maybeSingle()
  if (!student) return
  const tokens = await tokensForPhones([
    student.parent_phone_1,
    student.parent_phone_2,
  ])
  const label = status === 'absent' ? 'Absence' : 'Retard'
  await sendToTokens(tokens, label, `${student.full_name}: ${label.toLowerCase()}`, {
    type: 'attendance',
  })
}

async function onAnnouncement(record: any) {
  const audience = record.audience as string
  const tokens: string[] = []

  if (audience === 'teachers' || audience === 'both') {
    const { data } = await admin
      .from('memberships')
      .select('user_id')
      .eq('school_id', record.school_id)
      .eq('role', 'teacher')
      .not('user_id', 'is', null)
    tokens.push(
      ...(await tokensForUserIds((data ?? []).map((r: any) => r.user_id))),
    )
  }

  if (audience === 'parents' || audience === 'both') {
    let q = admin
      .from('students')
      .select('parent_phone_1, parent_phone_2')
      .eq('school_id', record.school_id)
    if (record.class_id) q = q.eq('class_id', record.class_id)
    const { data } = await q
    const phones: string[] = []
    for (const s of data ?? []) {
      if (s.parent_phone_1) phones.push(s.parent_phone_1)
      if (s.parent_phone_2) phones.push(s.parent_phone_2)
    }
    tokens.push(...(await tokensForPhones(phones)))
  }

  // de-dupe
  const unique = [...new Set(tokens)]
  await sendToTokens(unique, record.title ?? 'Annonce', record.body ?? '', {
    type: 'announcement',
  })
}

serve(async (req) => {
  try {
    const secret = Deno.env.get('WEBHOOK_SECRET')
    if (secret && req.headers.get('x-webhook-secret') !== secret) {
      return new Response('unauthorized', { status: 401 })
    }
    const payload = await req.json()
    const table = payload.table as string
    const type = payload.type as string // INSERT | UPDATE | DELETE
    const record = payload.record
    const oldRecord = payload.old_record
    if (!record || type === 'DELETE') {
      return new Response(JSON.stringify({ skipped: true }), { status: 200 })
    }

    if (table === 'grades') await onGrade(record)
    else if (table === 'attendance')
      await onAttendance(record, oldRecord, type === 'INSERT')
    else if (table === 'announcements') await onAnnouncement(record)

    return new Response(JSON.stringify({ ok: true }), {
      headers: { 'Content-Type': 'application/json' },
      status: 200,
    })
  } catch (e) {
    console.error('send-push error:', e)
    return new Response(JSON.stringify({ error: String(e) }), { status: 200 })
  }
})
