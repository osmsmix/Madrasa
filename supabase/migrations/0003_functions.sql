-- Madrasa — 0003 RPCs
-- Run AFTER 0002_rls.sql.

-- Atomically create a school and make the caller its director.
-- SECURITY DEFINER so it can seed the first director membership (which the RLS
-- policies would otherwise forbid). Callable by any signed-in user.
--
-- IMPORTANT: this MUST live in `public`, not `app` — Supabase's PostgREST only
-- exposes the `public` schema over the API, so an RPC in `app` is not callable
-- via supabase.rpc(). The RLS helper functions stay in `app` (they're called
-- from policies in SQL, not over the API).
drop function if exists app.create_school_with_director(text, term_type, numeric);

create or replace function public.create_school_with_director(
  p_name      text,
  p_term_type term_type default 'trimester',
  p_grade_max numeric default 20
)
returns schools
language plpgsql
security definer
set search_path = public
as $$
declare
  v_phone  text := app.current_phone();
  v_school schools;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;
  if v_phone is null then
    raise exception 'no verified phone on account';
  end if;

  insert into schools (name, term_type, grade_max)
  values (p_name, p_term_type, p_grade_max)
  returning * into v_school;

  insert into memberships (school_id, role, phone, user_id)
  values (v_school.id, 'director', v_phone, auth.uid());

  return v_school;
end;
$$;

grant execute on function public.create_school_with_director(text, term_type, numeric) to authenticated;
grant execute on function app.current_phone() to authenticated;
grant usage on schema app to authenticated;
