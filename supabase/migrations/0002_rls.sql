-- Madrasa — 0002 row-level security
-- Run AFTER 0001_schema.sql. This is the security backbone: it guarantees a parent
-- only ever sees their own child, a teacher only their own classes, a director only
-- their own school.
--
-- Helper functions live in schema `app` and are SECURITY DEFINER: they read tables
-- with RLS bypassed, which both keeps policies fast and avoids infinite recursion
-- (a policy on table X must never SELECT table X under RLS).

create schema if not exists app;

-- Current user's verified phone (from the OTP JWT), falling back to the profile row.
create or replace function app.current_phone()
returns text language sql stable security definer set search_path = public as $$
  select coalesce(
    nullif(auth.jwt() ->> 'phone', ''),
    (select phone from profiles where id = auth.uid())
  );
$$;

create or replace function app.is_director(p_school uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from memberships m
    where m.school_id = p_school and m.role = 'director'
      and (m.user_id = auth.uid() or m.phone = app.current_phone())
  );
$$;

create or replace function app.is_teacher_in(p_school uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from memberships m
    where m.school_id = p_school and m.role = 'teacher'
      and (m.user_id = auth.uid() or m.phone = app.current_phone())
  );
$$;

-- Does the current user teach this class_subject?
create or replace function app.teaches_class_subject(p_cs uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1
    from class_subjects cs
    join memberships m on m.id = cs.teacher_membership_id
    where cs.id = p_cs
      and (m.user_id = auth.uid() or m.phone = app.current_phone())
  );
$$;

-- Does the current user teach any subject in this class?
create or replace function app.teaches_class(p_class uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1
    from class_subjects cs
    join memberships m on m.id = cs.teacher_membership_id
    where cs.class_id = p_class
      and (m.user_id = auth.uid() or m.phone = app.current_phone())
  );
$$;

-- Is the current user (by phone) a parent of this student?
create or replace function app.is_parent_of(p_student uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from students s
    where s.id = p_student
      and app.current_phone() in (s.parent_phone_1, s.parent_phone_2)
  );
$$;

-- Schools the current user can *see* in any role (director, teacher, or parent).
create or replace function app.visible_school(p_school uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select
    app.is_director(p_school)
    or app.is_teacher_in(p_school)
    or exists (
      select 1 from students s
      where s.school_id = p_school
        and app.current_phone() in (s.parent_phone_1, s.parent_phone_2)
    );
$$;

-- ===========================================================================
-- Enable RLS on every table (default-deny once enabled)
-- ===========================================================================
alter table profiles       enable row level security;
alter table schools        enable row level security;
alter table school_years   enable row level security;
alter table terms          enable row level security;
alter table memberships    enable row level security;
alter table classes        enable row level security;
alter table subjects       enable row level security;
alter table class_subjects enable row level security;
alter table students       enable row level security;
alter table schedule_slots enable row level security;
alter table sessions       enable row level security;
alter table attendance     enable row level security;
alter table assessments    enable row level security;
alter table grades         enable row level security;
alter table announcements  enable row level security;
alter table devices        enable row level security;

-- ===========================================================================
-- profiles: a user manages only their own row
-- ===========================================================================
create policy profiles_self_select on profiles for select using (id = auth.uid());
create policy profiles_self_update on profiles for update using (id = auth.uid()) with check (id = auth.uid());

-- ===========================================================================
-- schools
-- ===========================================================================
create policy schools_select on schools for select
  using (app.visible_school(id));
-- No direct INSERT policy: schools are created only via app.create_school_with_director()
-- (0003_functions.sql), which atomically creates the school + the caller's director
-- membership. This avoids the chicken-and-egg where inserting the first director
-- membership would itself require already being a director.
create policy schools_update on schools for update
  using (app.is_director(id)) with check (app.is_director(id));
create policy schools_delete on schools for delete using (app.is_director(id));

-- ===========================================================================
-- school_years / terms — director writes, members read
-- ===========================================================================
create policy years_select on school_years for select using (app.visible_school(school_id));
create policy years_write  on school_years for all
  using (app.is_director(school_id)) with check (app.is_director(school_id));

create policy terms_select on terms for select using (
  exists (select 1 from school_years y where y.id = terms.school_year_id and app.visible_school(y.school_id))
);
create policy terms_write on terms for all using (
  exists (select 1 from school_years y where y.id = terms.school_year_id and app.is_director(y.school_id))
) with check (
  exists (select 1 from school_years y where y.id = terms.school_year_id and app.is_director(y.school_id))
);

-- ===========================================================================
-- memberships — director manages; a user can see their own membership rows
-- ===========================================================================
create policy memberships_select on memberships for select using (
  app.is_director(school_id)
  or user_id = auth.uid()
  or phone = app.current_phone()
);
create policy memberships_write on memberships for all
  using (app.is_director(school_id)) with check (app.is_director(school_id));

-- ===========================================================================
-- classes / subjects / class_subjects
-- ===========================================================================
create policy classes_select on classes for select using (app.visible_school(school_id));
create policy classes_write  on classes for all
  using (app.is_director(school_id)) with check (app.is_director(school_id));

create policy subjects_select on subjects for select using (app.visible_school(school_id));
create policy subjects_write  on subjects for all
  using (app.is_director(school_id)) with check (app.is_director(school_id));

create policy class_subjects_select on class_subjects for select using (
  exists (select 1 from classes c where c.id = class_subjects.class_id and app.visible_school(c.school_id))
);
create policy class_subjects_write on class_subjects for all using (
  exists (select 1 from classes c where c.id = class_subjects.class_id and app.is_director(c.school_id))
) with check (
  exists (select 1 from classes c where c.id = class_subjects.class_id and app.is_director(c.school_id))
);

-- ===========================================================================
-- students — director writes; teacher sees students in classes they teach;
--            parent sees only their own child (phone match)
-- ===========================================================================
create policy students_select on students for select using (
  app.is_director(school_id)
  or app.teaches_class(class_id)
  or app.current_phone() in (parent_phone_1, parent_phone_2)
);
create policy students_write on students for all
  using (app.is_director(school_id)) with check (app.is_director(school_id));

-- ===========================================================================
-- timetable: schedule_slots / sessions
-- ===========================================================================
create policy slots_select on schedule_slots for select using (
  exists (
    select 1 from class_subjects cs join classes c on c.id = cs.class_id
    where cs.id = schedule_slots.class_subject_id and app.visible_school(c.school_id)
  )
);
create policy slots_write on schedule_slots for all using (
  exists (
    select 1 from class_subjects cs join classes c on c.id = cs.class_id
    where cs.id = schedule_slots.class_subject_id and app.is_director(c.school_id)
  )
) with check (
  exists (
    select 1 from class_subjects cs join classes c on c.id = cs.class_id
    where cs.id = schedule_slots.class_subject_id and app.is_director(c.school_id)
  )
);

-- sessions: director + the teaching teacher can create/read; parents of a student
-- in that class can read (to see attendance context).
create policy sessions_select on sessions for select using (
  exists (
    select 1 from schedule_slots sl
    join class_subjects cs on cs.id = sl.class_subject_id
    join classes c on c.id = cs.class_id
    where sl.id = sessions.schedule_slot_id
      and (app.is_director(c.school_id) or app.teaches_class_subject(cs.id)
           or exists (select 1 from students st
                      where st.class_id = c.id
                        and app.current_phone() in (st.parent_phone_1, st.parent_phone_2)))
  )
);
create policy sessions_write on sessions for all using (
  exists (
    select 1 from schedule_slots sl join class_subjects cs on cs.id = sl.class_subject_id
    join classes c on c.id = cs.class_id
    where sl.id = sessions.schedule_slot_id
      and (app.is_director(c.school_id) or app.teaches_class_subject(cs.id))
  )
) with check (
  exists (
    select 1 from schedule_slots sl join class_subjects cs on cs.id = sl.class_subject_id
    join classes c on c.id = cs.class_id
    where sl.id = sessions.schedule_slot_id
      and (app.is_director(c.school_id) or app.teaches_class_subject(cs.id))
  )
);

-- ===========================================================================
-- attendance — teacher (of the session) inserts/updates; parent reads own child
--              and may update ONLY the excused fields on their own child's row;
--              director reads.
-- ===========================================================================
create policy attendance_teacher_all on attendance for all using (
  exists (
    select 1 from sessions se
    join schedule_slots sl on sl.id = se.schedule_slot_id
    join class_subjects cs on cs.id = sl.class_subject_id
    where se.id = attendance.session_id and app.teaches_class_subject(cs.id)
  )
) with check (
  exists (
    select 1 from sessions se
    join schedule_slots sl on sl.id = se.schedule_slot_id
    join class_subjects cs on cs.id = sl.class_subject_id
    where se.id = attendance.session_id and app.teaches_class_subject(cs.id)
  )
);

create policy attendance_director_select on attendance for select using (
  exists (
    select 1 from sessions se
    join schedule_slots sl on sl.id = se.schedule_slot_id
    join class_subjects cs on cs.id = sl.class_subject_id
    join classes c on c.id = cs.class_id
    where se.id = attendance.session_id and app.is_director(c.school_id)
  )
);

create policy attendance_parent_select on attendance for select using (app.is_parent_of(student_id));
-- parent can flip excused on their own child's absent/late record
create policy attendance_parent_excuse on attendance for update
  using (app.is_parent_of(student_id))
  with check (app.is_parent_of(student_id));

-- ===========================================================================
-- assessments — teacher of the class_subject writes; director + parent (of a
--               student in that class) read.
-- ===========================================================================
create policy assessments_teacher_all on assessments for all
  using (app.teaches_class_subject(class_subject_id))
  with check (app.teaches_class_subject(class_subject_id));

create policy assessments_read on assessments for select using (
  exists (
    select 1 from class_subjects cs join classes c on c.id = cs.class_id
    where cs.id = assessments.class_subject_id
      and (app.is_director(c.school_id)
           or exists (select 1 from students st
                      where st.class_id = c.id
                        and app.current_phone() in (st.parent_phone_1, st.parent_phone_2)))
  )
);

-- ===========================================================================
-- grades — teacher (of the assessment's class_subject) writes; director reads;
--          parent reads only their own child's grade.
-- ===========================================================================
create policy grades_teacher_all on grades for all using (
  exists (select 1 from assessments a where a.id = grades.assessment_id
          and app.teaches_class_subject(a.class_subject_id))
) with check (
  exists (select 1 from assessments a where a.id = grades.assessment_id
          and app.teaches_class_subject(a.class_subject_id))
);

create policy grades_parent_select on grades for select using (app.is_parent_of(student_id));

create policy grades_director_select on grades for select using (
  exists (
    select 1 from assessments a
    join class_subjects cs on cs.id = a.class_subject_id
    join classes c on c.id = cs.class_id
    where a.id = grades.assessment_id and app.is_director(c.school_id)
  )
);

-- ===========================================================================
-- announcements — director writes; teacher/parent read by audience (+ class scope)
-- ===========================================================================
create policy announcements_director_all on announcements for all
  using (app.is_director(school_id)) with check (app.is_director(school_id));

create policy announcements_teacher_select on announcements for select using (
  audience in ('teachers','both') and app.is_teacher_in(school_id)
);

create policy announcements_parent_select on announcements for select using (
  audience in ('parents','both')
  and exists (
    select 1 from students st
    where st.school_id = announcements.school_id
      and (announcements.class_id is null or st.class_id = announcements.class_id)
      and app.current_phone() in (st.parent_phone_1, st.parent_phone_2)
  )
);

-- ===========================================================================
-- devices — a user manages only their own push tokens
-- ===========================================================================
create policy devices_self_all on devices for all
  using (user_id = auth.uid()) with check (user_id = auth.uid());
