-- Madrasa — demo/reviewer seed (3 schools, one per role)
-- The test phone becomes: DIRECTOR of school 1, TEACHER in school 2, PARENT in
-- school 3. Each school has its own fake data. On the "choose school and role"
-- screen the tester sees all three and can explore each role.
--
-- 1. Set v_phone (below, in every block) to your TEST_PHONE (E.164 w/o '+', e.g. 22200000000).
-- 2. Run once in the Supabase SQL Editor. Safe to re-run (it clears the demo schools first).

-- Idempotent cleanup: remove previous demo schools (cascades to all their data).
-- Includes 'École Démo' from the earlier single-school seed.
delete from schools
  where name in ('École Démo', 'Lycée El Nour', 'Collège Avenir', 'École La Paix');

-- ══════════════════════════════════════════════════════════════════════════
-- SCHOOL 1 — test phone is DIRECTOR
-- ══════════════════════════════════════════════════════════════════════════
do $$
declare
  v_phone text := '22200000000';   -- <-- your TEST_PHONE
  sch uuid; yr uuid; t1 uuid;
  cA uuid; cB uuid;
  sMath uuid; sAr uuid; sFr uuid;
  tAhmed uuid; tMariem uuid;
  csMath uuid;
  slot uuid; sess uuid; asmt uuid;
begin
  insert into schools(name, term_type, grade_max, is_active)
    values ('Lycée El Nour', 'trimester', 20, true) returning id into sch;
  insert into school_years(school_id, label, is_active)
    values (sch, '2026-2027', true) returning id into yr;
  insert into terms(school_year_id, idx, label)
    values (yr,1,'T1'), (yr,2,'T2'), (yr,3,'T3');
  select id into t1 from terms where school_year_id = yr and idx = 1;

  insert into classes(school_id, school_year_id, name) values (sch, yr, '6ème A') returning id into cA;
  insert into classes(school_id, school_year_id, name) values (sch, yr, '6ème B') returning id into cB;

  insert into subjects(school_id, name) values (sch,'Mathématiques') returning id into sMath;
  insert into subjects(school_id, name) values (sch,'Arabe') returning id into sAr;
  insert into subjects(school_id, name) values (sch,'Français') returning id into sFr;

  insert into memberships(school_id, role, phone, full_name)
    values (sch, 'director', v_phone, 'Directeur (démo)');
  insert into memberships(school_id, role, phone, full_name)
    values (sch, 'teacher', '22231000001', 'Ahmedou Ba') returning id into tAhmed;
  insert into memberships(school_id, role, phone, full_name)
    values (sch, 'teacher', '22231000002', 'Mariem Sy') returning id into tMariem;

  insert into class_subjects(class_id, subject_id, teacher_membership_id, coefficient)
    values (cA, sMath, tAhmed, 3) returning id into csMath;
  insert into class_subjects(class_id, subject_id, teacher_membership_id, coefficient)
    values (cA, sAr, tMariem, 2);
  insert into class_subjects(class_id, subject_id, teacher_membership_id, coefficient)
    values (cA, sFr, tMariem, 2);

  insert into students(school_id, class_id, full_name, parent_phone_1) values
    (sch, cA, 'Yahya Ahmed', '22232000001'),
    (sch, cA, 'Fatimetou Salem', '22232000002'),
    (sch, cA, 'Sidi Brahim', '22232000003'),
    (sch, cB, 'Aicha Moulaye', '22232000004');

  insert into schedule_slots(class_subject_id, weekday, start_time, end_time, room)
    values (csMath, extract(isodow from current_date)::int, '08:00', '09:00', 'Salle 1')
    returning id into slot;

  -- a little activity so the dashboard/sections aren't empty
  insert into assessments(class_subject_id, term_id, type, title, date, max_grade, coefficient)
    values (csMath, t1, 'exam', 'Devoir 1', current_date, 20, 2) returning id into asmt;
  insert into grades(assessment_id, student_id, value)
    select asmt, id, 14 from students where class_id = cA limit 3;
  insert into sessions(schedule_slot_id, date) values (slot, current_date) returning id into sess;
  insert into attendance(session_id, student_id, status)
    select sess, id, 'present' from students where class_id = cA;
end $$;

-- ══════════════════════════════════════════════════════════════════════════
-- SCHOOL 2 — test phone is TEACHER
-- ══════════════════════════════════════════════════════════════════════════
do $$
declare
  v_phone text := '22200000000';   -- <-- your TEST_PHONE
  sch uuid; yr uuid; t1 uuid; c5 uuid;
  sMath uuid; sPhys uuid;
  tMe uuid; tOther uuid;
  csMath uuid; csPhys uuid; asmt uuid;
begin
  insert into schools(name, term_type, grade_max, is_active)
    values ('Collège Avenir', 'trimester', 20, true) returning id into sch;
  insert into school_years(school_id, label, is_active)
    values (sch, '2026-2027', true) returning id into yr;
  insert into terms(school_year_id, idx, label)
    values (yr,1,'T1'), (yr,2,'T2'), (yr,3,'T3');
  select id into t1 from terms where school_year_id = yr and idx = 1;

  insert into classes(school_id, school_year_id, name) values (sch, yr, '5ème A') returning id into c5;
  insert into subjects(school_id, name) values (sch,'Mathématiques') returning id into sMath;
  insert into subjects(school_id, name) values (sch,'Physique') returning id into sPhys;

  insert into memberships(school_id, role, phone, full_name)
    values (sch, 'director', '22240000000', 'Directrice Avenir');
  -- the test phone is a TEACHER here
  insert into memberships(school_id, role, phone, full_name)
    values (sch, 'teacher', v_phone, 'Enseignant (démo)') returning id into tMe;
  insert into memberships(school_id, role, phone, full_name)
    values (sch, 'teacher', '22241000001', 'Brahim Kane') returning id into tOther;

  -- test teacher teaches Maths; another teacher does Physique
  insert into class_subjects(class_id, subject_id, teacher_membership_id, coefficient)
    values (c5, sMath, tMe, 3) returning id into csMath;
  insert into class_subjects(class_id, subject_id, teacher_membership_id, coefficient)
    values (c5, sPhys, tOther, 2) returning id into csPhys;

  insert into students(school_id, class_id, full_name, parent_phone_1) values
    (sch, c5, 'Moulaye Idriss', '22242000001'),
    (sch, c5, 'Zeinabou Ely', '22242000002'),
    (sch, c5, 'Cheikh Vall', '22242000003'),
    (sch, c5, 'Khadijetou Sow', '22242000004');

  -- Maths sessions on today + a couple of weekdays, so "Today" and the weekly
  -- schedule both show the test teacher's classes.
  insert into schedule_slots(class_subject_id, weekday, start_time, end_time, room)
    values
      (csMath, extract(isodow from current_date)::int, '08:00', '09:00', 'Salle 3'),
      (csMath, extract(isodow from current_date)::int, '10:00', '11:00', 'Salle 3'),
      (csPhys, extract(isodow from current_date)::int, '11:00', '12:00', 'Labo');

  -- one existing assessment so the Grades tab isn't empty (grades left blank to fill live)
  insert into assessments(class_subject_id, term_id, type, title, date, max_grade, coefficient)
    values (csMath, t1, 'test', 'Contrôle continu', current_date, 20, 1) returning id into asmt;
end $$;

-- ══════════════════════════════════════════════════════════════════════════
-- SCHOOL 3 — test phone is PARENT (of one student)
-- ══════════════════════════════════════════════════════════════════════════
do $$
declare
  v_phone text := '22200000000';   -- <-- your TEST_PHONE
  sch uuid; yr uuid; t1 uuid; cce uuid;
  sMath uuid; sAr uuid;
  tOther uuid; csMath uuid; csAr uuid;
  child uuid; slotM uuid; slotA uuid;
  sess uuid; asmtM uuid; asmtA uuid;
begin
  insert into schools(name, term_type, grade_max, is_active)
    values ('École La Paix', 'trimester', 20, true) returning id into sch;
  insert into school_years(school_id, label, is_active)
    values (sch, '2026-2027', true) returning id into yr;
  insert into terms(school_year_id, idx, label)
    values (yr,1,'T1'), (yr,2,'T2'), (yr,3,'T3');
  select id into t1 from terms where school_year_id = yr and idx = 1;

  insert into classes(school_id, school_year_id, name) values (sch, yr, 'CE2') returning id into cce;
  insert into subjects(school_id, name) values (sch,'Mathématiques') returning id into sMath;
  insert into subjects(school_id, name) values (sch,'Arabe') returning id into sAr;

  insert into memberships(school_id, role, phone, full_name)
    values (sch, 'director', '22250000000', 'Directeur La Paix');
  insert into memberships(school_id, role, phone, full_name)
    values (sch, 'teacher', '22251000001', 'Aicha Diallo') returning id into tOther;

  insert into class_subjects(class_id, subject_id, teacher_membership_id, coefficient)
    values (cce, sMath, tOther, 3) returning id into csMath;
  insert into class_subjects(class_id, subject_id, teacher_membership_id, coefficient)
    values (cce, sAr, tOther, 2) returning id into csAr;

  -- the test phone is this child's parent
  insert into students(school_id, class_id, full_name, parent_phone_1)
    values (sch, cce, 'Mon Enfant (démo)', v_phone) returning id into child;
  insert into students(school_id, class_id, full_name) values
    (sch, cce, 'Oumar Ndiaye'), (sch, cce, 'Salma Ould');

  -- grades for the child (so the Parent → Grades view is populated)
  insert into assessments(class_subject_id, term_id, type, title, date, max_grade, coefficient)
    values (csMath, t1, 'exam', 'Examen 1', current_date - 7, 20, 3) returning id into asmtM;
  insert into assessments(class_subject_id, term_id, type, title, date, max_grade, coefficient)
    values (csAr, t1, 'homework', 'Devoir maison', current_date - 3, 20, 1) returning id into asmtA;
  insert into grades(assessment_id, student_id, value) values (asmtM, child, 16);
  insert into grades(assessment_id, student_id, value) values (asmtA, child, 12);

  -- attendance for the child (one absence to demo the "excuse" feature)
  insert into schedule_slots(class_subject_id, weekday, start_time, end_time, room)
    values (csMath, extract(isodow from (current_date - 2))::int, '09:00', '10:00', 'Salle A')
    returning id into slotM;
  insert into sessions(schedule_slot_id, date) values (slotM, current_date - 2) returning id into sess;
  insert into attendance(session_id, student_id, status) values (sess, child, 'absent');

  insert into schedule_slots(class_subject_id, weekday, start_time, end_time, room)
    values (csAr, extract(isodow from (current_date - 1))::int, '10:00', '11:00', 'Salle A')
    returning id into slotA;
  insert into sessions(schedule_slot_id, date) values (slotA, current_date - 1) returning id into sess;
  insert into attendance(session_id, student_id, status) values (sess, child, 'late');
end $$;
