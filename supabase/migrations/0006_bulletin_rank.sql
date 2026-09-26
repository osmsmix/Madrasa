-- Madrasa — 0006 class rank for report cards
-- Computes a student's rank in their class for a term (or the whole year when
-- p_term is null), using the SAME two-level weighting as the app's overall
-- average. SECURITY DEFINER so it can read every classmate's grades, but it
-- returns ONLY {rank, total} — no other student's data is exposed.

create or replace function public.bulletin_rank(p_student uuid, p_term uuid default null)
returns table(the_rank int, the_total int)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_class  uuid;
  v_school uuid;
begin
  select class_id, school_id into v_class, v_school from students where id = p_student;
  if v_class is null then
    return;
  end if;
  -- Only someone who can see the school (its director/teacher, or a parent of a
  -- student in it) may compute ranks in it.
  if not app.visible_school(v_school) then
    raise exception 'not allowed';
  end if;

  return query
  with per_subject as (
    select g.student_id,
           cs.id as cs_id,
           cs.coefficient as scoef,
           sum((g.value / a.max_grade) * a.coefficient)
             / nullif(sum(a.coefficient), 0) as frac
    from grades g
    join assessments a on a.id = g.assessment_id
    join class_subjects cs on cs.id = a.class_subject_id
    where g.value is not null
      and a.max_grade > 0
      and cs.class_id = v_class
      and (p_term is null or a.term_id = p_term)
    group by g.student_id, cs.id, cs.coefficient
  ),
  per_student as (
    select student_id,
           sum(frac * scoef) / nullif(sum(scoef), 0) as overall
    from per_subject
    group by student_id
  ),
  ranked as (
    select student_id,
           rank() over (order by overall desc) as rnk,
           count(*) over () as total
    from per_student
  )
  select ranked.rnk::int, ranked.total::int
  from ranked
  where ranked.student_id = p_student;
end;
$$;

grant execute on function public.bulletin_rank(uuid, uuid) to authenticated;
