-- Madrasa — 0004 school activation gate
-- A school is created DEACTIVATED. Until you (the vendor) set is_active = true,
-- it is invisible and unusable to teachers and parents, and the director sees a
-- "pending activation" screen. Run AFTER 0003_functions.sql.

alter table schools
  add column if not exists is_active boolean not null default false;

-- Keep already-created schools usable (they predate this gate).
update schools set is_active = true where is_active = false;

-- Helper: is this school activated?
create or replace function app.school_is_active(p_school uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce((select is_active from schools where id = p_school), false);
$$;

-- Directors always see their own school (to view its pending status). Teachers
-- and parents only see a school once it is ACTIVE. This gates every read that
-- goes through visible_school (schools, classes, students, sessions, …).
create or replace function app.visible_school(p_school uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select
    app.is_director(p_school)
    or (
      app.school_is_active(p_school)
      and (
        app.is_teacher_in(p_school)
        or exists (
          select 1 from students s
          where s.school_id = p_school
            and app.current_phone() in (s.parent_phone_1, s.parent_phone_2)
        )
      )
    );
$$;

-- New schools default to inactive (the column default handles it). The vendor
-- activates one with, e.g.:
--   update schools set is_active = true where id = '...';
