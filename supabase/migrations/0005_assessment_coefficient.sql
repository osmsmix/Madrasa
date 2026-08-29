-- Madrasa — 0005 per-assessment coefficient
-- Each assessment (exam/homework/test) carries its own weight, set by the
-- teacher, used when computing the subject average. Run AFTER 0004.

alter table assessments
  add column if not exists coefficient numeric(4,2) not null default 1;
