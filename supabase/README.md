# Supabase — Madrasa

SQL migrations for the Madrasa backend. Apply them **in order**.

```
migrations/
  0001_schema.sql      tables, enums, auth trigger (profile + membership claim)
  0002_rls.sql         RLS: helper functions (schema `app`) + policies on every table
  0003_functions.sql   create_school_with_director() RPC + grants
```

## Apply

**Option A — Dashboard (quickest):** open the project → SQL Editor → paste each file's
contents in order (0001, 0002, 0003) and run.

**Option B — CLI:**
```bash
supabase link --project-ref <your-ref>
supabase db push        # if using the migrations workflow
# or run each file:
psql "$SUPABASE_DB_URL" -f migrations/0001_schema.sql
psql "$SUPABASE_DB_URL" -f migrations/0002_rls.sql
psql "$SUPABASE_DB_URL" -f migrations/0003_functions.sql
```

## Auth setup — ChinqIT (not native Supabase phone OTP)

We use the **ChinqIT** gateway (`https://sms.chinqit.com/api/v2`), which both
*generates* and *verifies* the code. Supabase's built-in phone provider is therefore
**not** used. Two Edge Functions wrap it:

```
functions/
  _shared/cors.ts      shared headers + ChinqIT base URL + default channel
  send-otp/            POST /code  → ChinqIT sends the code
  verify-otp/          POST /check → verifies, then creates/refreshes the auth user
```

**Flow (passwordless from the user's side):**
1. Client → `send-otp` `{ phone_number }` → ChinqIT delivers the code (SMS or WhatsApp).
2. Client generates a **random throwaway password**, then → `verify-otp`
   `{ phone_number, user_code, password, full_name? }`.
3. `verify-otp` checks the code, then (service role) creates the auth user with
   `phone_confirm: true` and sets that password. The `on_auth_user_created` trigger
   creates the `profiles` row and backfills any teacher/director `memberships` the
   director pre-entered by phone.
4. Client calls `supabase.auth.signInWithPassword({ phone, password })` → session.
   The user never sees or types a password; the persistent session takes over.

**Deploy + secrets (CLI):**
```bash
supabase functions deploy send-otp
supabase functions deploy verify-otp
supabase secrets set CHINQIT_API_KEY=<your-key>
# optional: default channel is 'whatsapp'; set to 'sms' to switch
# supabase secrets set CHINQIT_CHANNEL=sms
```
`SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` are injected into functions automatically.

> Channel note: the default is **`whatsapp`**. Override globally with the
> `CHINQIT_CHANNEL` secret, or per request from the client.

## The one convention that will bite you: phone format
All phones must be stored in the **same shape Supabase Auth uses** for
`auth.users.phone` — **E.164 without the leading `+`** (e.g. `213661234567`).
Parents are matched to students purely by phone, and teachers by membership phone;
if the director's UI stores `+213 66 12 34 57` or `0661234567`, matching silently
fails and the user sees nothing. **Normalise every phone to this format before insert.**

## How access is enforced (mental model)
- **Identity = phone.** `app.current_phone()` reads the verified phone from the JWT.
- **Director**: has a `memberships` row with role `director` → full CRUD on their school.
- **Teacher**: `memberships` role `teacher`; assigned to classes via
  `class_subjects.teacher_membership_id`. Sees/writes only their own classes,
  sessions, attendance, assessments, grades.
- **Parent**: no membership — matched to students by
  `students.parent_phone_1 / _2 = current_phone()`. Read-only on their child's
  grades/attendance/announcements; may set the `excused` fields on their child's row.
- RLS is **default-deny**: once enabled, only the written policies grant access.
  The `service_role` key bypasses RLS — use it **only** server-side (e.g. the FCM
  push function), never in the app.

## Creating the first school (from the app)
Call the RPC rather than inserting into `schools` directly:
```dart
final school = await supabase.rpc('create_school_with_director', params: {
  'p_name': 'Madrasa X',
  'p_term_type': 'trimester', // or 'semester'
  'p_grade_max': 20,
});
```
This creates the school and the caller's director membership atomically.

## Not yet included (later migrations)
- FCM fan-out (triggers/edge function) for: new grade, absent/late, announcement.
- `sessions` auto-generation from `schedule_slots` for a date range.
- Report-card / bulletin views (built last).
```
