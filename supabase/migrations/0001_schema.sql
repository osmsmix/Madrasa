-- Madrasa — 0001 schema
-- Postgres / Supabase. Run before 0002_rls.sql.
--
-- Identity model: phone number = one global user. Directors enter teacher/parent
-- phone numbers as *data* before those users exist; access activates when the
-- phone verifies (Supabase phone OTP). Parents are matched to students purely by
-- phone (students.parent_phone_1 / _2), so no separate parent_links table is
-- needed. Teachers are matched through memberships (which carry the phone and get
-- their user_id backfilled on first login).
--
-- Phone format convention: store all phones in the SAME shape Supabase Auth uses
-- for `auth.users.phone` — E.164 WITHOUT the leading '+' (e.g. 213661234567).
-- The director UI must normalise to this before insert, or matching will silently fail.

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------------
-- Enums
-- ---------------------------------------------------------------------------
create type term_type            as enum ('trimester', 'semester');
create type membership_role      as enum ('director', 'teacher');
create type attendance_status    as enum ('present', 'absent', 'late');
create type assessment_type      as enum ('exam', 'homework', 'test');
create type announcement_audience as enum ('teachers', 'parents', 'both');

-- ---------------------------------------------------------------------------
-- profiles: 1:1 with auth.users, auto-created by trigger below
-- ---------------------------------------------------------------------------
create table profiles (
  id             uuid primary key references auth.users (id) on delete cascade,
  phone          text unique not null,
  full_name      text,
  preferred_lang text not null default 'ar' check (preferred_lang in ('ar','fr','en')),
  created_at     timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- schools & academic calendar
-- ---------------------------------------------------------------------------
create table schools (
  id         uuid primary key default gen_random_uuid(),
  name       text not null,
  term_type  term_type not null default 'trimester',
  grade_max  numeric(5,2) not null default 20,   -- e.g. 20 for /20
  created_at timestamptz not null default now()
);

create table school_years (
  id         uuid primary key default gen_random_uuid(),
  school_id  uuid not null references schools (id) on delete cascade,
  label      text not null,                       -- e.g. '2026-2027'
  starts_on  date,
  ends_on    date,
  is_active  boolean not null default true,
  created_at timestamptz not null default now()
);

create table terms (
  id             uuid primary key default gen_random_uuid(),
  school_year_id uuid not null references school_years (id) on delete cascade,
  idx            int  not null,                    -- 1..3 (trimester) or 1..2 (semester)
  label          text not null,
  starts_on      date,
  ends_on        date,
  unique (school_year_id, idx)
);

-- ---------------------------------------------------------------------------
-- people links to a school
-- ---------------------------------------------------------------------------
-- membership carries the phone so a director can add a teacher before they log in.
-- user_id is backfilled by the handle_new_user() trigger on first verification.
create table memberships (
  id         uuid primary key default gen_random_uuid(),
  school_id  uuid not null references schools (id) on delete cascade,
  role       membership_role not null,
  phone      text not null,
  user_id    uuid references auth.users (id) on delete set null,
  full_name  text,
  created_at timestamptz not null default now(),
  unique (school_id, phone, role)
);
create index on memberships (phone);
create index on memberships (user_id);

-- ---------------------------------------------------------------------------
-- classes / subjects / class-subject (coefficient + teacher live here, per class)
-- ---------------------------------------------------------------------------
create table classes (
  id             uuid primary key default gen_random_uuid(),
  school_id      uuid not null references schools (id) on delete cascade,
  school_year_id uuid not null references school_years (id) on delete cascade,
  name           text not null,
  created_at     timestamptz not null default now()
);
create index on classes (school_id);

create table subjects (
  id         uuid primary key default gen_random_uuid(),
  school_id  uuid not null references schools (id) on delete cascade,
  name       text not null,
  created_at timestamptz not null default now()
);
create index on subjects (school_id);

-- one row per (class taught a subject), holding the per-class coefficient and the
-- assigned teacher (as a membership, so assignable before the teacher logs in).
create table class_subjects (
  id                    uuid primary key default gen_random_uuid(),
  class_id              uuid not null references classes (id) on delete cascade,
  subject_id            uuid not null references subjects (id) on delete cascade,
  teacher_membership_id uuid references memberships (id) on delete set null,
  coefficient           numeric(4,2) not null default 1,
  created_at            timestamptz not null default now(),
  unique (class_id, subject_id)
);
create index on class_subjects (class_id);
create index on class_subjects (teacher_membership_id);

-- ---------------------------------------------------------------------------
-- students (up to 2 parent phones; parents matched by phone via RLS)
-- ---------------------------------------------------------------------------
create table students (
  id             uuid primary key default gen_random_uuid(),
  school_id      uuid not null references schools (id) on delete cascade,
  class_id       uuid references classes (id) on delete set null,
  full_name      text not null,
  parent_phone_1 text,
  parent_phone_2 text,
  created_at     timestamptz not null default now()
);
create index on students (class_id);
create index on students (school_id);
create index on students (parent_phone_1);
create index on students (parent_phone_2);

-- ---------------------------------------------------------------------------
-- timetable: recurring weekly slots -> concrete dated sessions
-- ---------------------------------------------------------------------------
create table schedule_slots (
  id               uuid primary key default gen_random_uuid(),
  class_subject_id uuid not null references class_subjects (id) on delete cascade,
  weekday          int  not null check (weekday between 1 and 7),  -- ISO: Mon=1..Sun=7
  start_time       time not null,
  end_time         time not null,
  room             text,
  created_at       timestamptz not null default now(),
  check (end_time > start_time)
);
create index on schedule_slots (class_subject_id);

create table sessions (
  id               uuid primary key default gen_random_uuid(),
  schedule_slot_id uuid not null references schedule_slots (id) on delete cascade,
  date             date not null,
  created_at       timestamptz not null default now(),
  unique (schedule_slot_id, date)
);
create index on sessions (date);

create table attendance (
  id            uuid primary key default gen_random_uuid(),
  session_id    uuid not null references sessions (id) on delete cascade,
  student_id    uuid not null references students (id) on delete cascade,
  status        attendance_status not null default 'present',
  excused       boolean not null default false,     -- parent-set on absent/late
  excuse_reason text,
  excused_by    uuid references auth.users (id) on delete set null,
  excused_at    timestamptz,
  created_at    timestamptz not null default now(),
  unique (session_id, student_id)
);
create index on attendance (student_id);

-- ---------------------------------------------------------------------------
-- assessments & grades
-- ---------------------------------------------------------------------------
create table assessments (
  id               uuid primary key default gen_random_uuid(),
  class_subject_id uuid not null references class_subjects (id) on delete cascade,
  term_id          uuid not null references terms (id) on delete cascade,
  type             assessment_type not null,
  title            text not null,
  date             date not null default current_date,
  max_grade        numeric(5,2) not null default 20,
  created_by       uuid references auth.users (id) on delete set null,
  created_at       timestamptz not null default now()
);
create index on assessments (class_subject_id);
create index on assessments (term_id);

create table grades (
  id            uuid primary key default gen_random_uuid(),
  assessment_id uuid not null references assessments (id) on delete cascade,
  student_id    uuid not null references students (id) on delete cascade,
  value         numeric(5,2),
  created_at    timestamptz not null default now(),
  unique (assessment_id, student_id)
);
create index on grades (student_id);

-- ---------------------------------------------------------------------------
-- announcements & push tokens
-- ---------------------------------------------------------------------------
create table announcements (
  id         uuid primary key default gen_random_uuid(),
  school_id  uuid not null references schools (id) on delete cascade,
  class_id   uuid references classes (id) on delete cascade,  -- null = whole audience
  audience   announcement_audience not null,
  title      text not null,
  body       text,
  created_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now()
);
create index on announcements (school_id);

create table devices (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references auth.users (id) on delete cascade,
  fcm_token  text not null,
  platform   text,
  updated_at timestamptz not null default now(),
  unique (user_id, fcm_token)
);

-- ---------------------------------------------------------------------------
-- auth trigger: create profile + claim pending memberships on first login
-- ---------------------------------------------------------------------------
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, phone)
  values (new.id, new.phone)
  on conflict (id) do update set phone = excluded.phone;

  -- backfill any teacher/director memberships the director pre-created by phone
  update public.memberships
     set user_id = new.id
   where phone = new.phone
     and user_id is null;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();
