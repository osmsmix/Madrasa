# Madrasa — Spec (v1)

School management + parent communication app. One Flutter codebase for **web + mobile**.
Backend: **Supabase** (Postgres, Auth, RLS, Realtime). Push: **Firebase Cloud Messaging**.

## Roles

| Role | Platform | Does |
|------|----------|------|
| **Director** | Web dashboard (+ mobile) | Creates school, year, classes, subjects, teachers, students, timetable; sends announcements; configures grade scale, coefficients, term structure, print format (print built last) |
| **Teacher** | Mobile | Sees own schedule → today's sessions → marks attendance; creates assessments → enters grades |
| **Parent** | Mobile | Sees each child's grades + attendance; marks absences excused; receives push |

## Identity model (critical)
- **Phone number = one global user.** Not owned by any school.
- Users connect to schools via **memberships** (director/teacher) and **parent_links** (parent).
- Same person can be teacher in School A and parent in School B — one login, role depends on the link.
- Director enters phone numbers as **data**; they activate into real linked accounts when that phone first verifies (claim-on-first-login).
- Students carry up to **2 parent phone numbers**; both parents (and multi-school parents) supported.

## Auth — ChinqIT gateway (not native Supabase phone OTP)
- SMS/WhatsApp OTP via **ChinqIT** (`https://sms.chinqit.com/api/v2`), which both
  generates and verifies the code. Native Supabase phone provider is **not** used.
- Two Edge Functions: `send-otp` (POST `/code`) and `verify-otp` (POST `/check`).
- **Passwordless UX**: client generates a random throwaway password; `verify-otp`
  verifies the code then creates/refreshes the auth user (service role,
  `phone_confirm: true`) and sets that password; client then
  `signInWithPassword({ phone, password })`. User never sees a password; session persists.
- On first sign-in the `handle_new_user` trigger creates the profile and backfills
  teacher/director memberships by phone. Parents are matched to students by phone (RLS).
- Default channel **whatsapp** (configurable to `sms` via `CHINQIT_CHANNEL`).
- **RLS is the security backbone** — it prevents any parent seeing another child. Schema + RLS built first.
- Phone format everywhere: **E.164 without `+`** (e.g. `213661234567`).

## Config / conventions
- **Term structure:** school setting — `trimester` (3) or `semester` (2). Averages grouped per term.
- **Grade scale:** director-chosen (e.g. /20). Assessments store `max_grade`.
- **Coefficient:** per class (on the class↔subject link), not global per subject.
- **Assessment types:** exam / homework / test.
- **Attendance status:** present / absent / late. Absent/late can be marked **excused** by a parent (reason optional).
- **Languages:** Arabic (default) / French / English. **RTL required in v1** (Arabic default or device language).

## Announcements
- Director picks **audience**: teachers only / parents only / both. Optionally scoped to a class.

## Data model (draft)
```
users            (id, phone, full_name, preferred_lang)
schools          (id, name, term_type: trimester|semester, grade_max, ...)
school_years     (id, school_id, label, start, end)
terms            (id, school_year_id, index, label, start, end)
memberships      (user_id, school_id, role: director|teacher)
classes          (id, school_id, year_id, name)
subjects         (id, school_id, name)
class_subjects   (id, class_id, subject_id, teacher_id, coefficient)   ← coefficient per class
students         (id, school_id, class_id, full_name, parent_phone_1, parent_phone_2)
parent_links     (user_id, student_id)                 ← activated on parent phone verify
schedule_slots   (id, class_subject_id, weekday, start_time, end_time, room)
sessions         (id, schedule_slot_id, date)          ← concrete day's instance
attendance       (id, session_id, student_id, status, excused, excuse_reason, excused_by, excused_at)
assessments      (id, class_subject_id, term_id, type, title, date, max_grade, created_by)
grades           (id, assessment_id, student_id, value)
announcements    (id, school_id, class_id?, audience: teachers|parents|both, title, body, created_at)
devices          (user_id, fcm_token, platform)        ← for push
```

## Notifications (FCM triggers)
1. New grade posted → parents of that student.
2. Child marked absent/late → parents of that student.
3. Director announcement → its audience.

## v1 build order
1. Supabase **schema + RLS** (security backbone).
2. **Auth**: phone OTP + claim-on-first-login + role routing.
3. **Director setup**: school → year/terms → classes → subjects → teachers → students → timetable → announcements.
4. **Teacher**: today's schedule → attendance; assessments → grades.
5. **Parent**: children → grades + attendance; mark excused.
6. **FCM push** for the 3 triggers.
7. **Report cards / print format** (bulletins) — built last.

## Deferred / later
- Report-card PDF printing and print-format config.
