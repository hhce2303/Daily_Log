-- daily_audit_log.id is bigint NOT NULL but had no default sequence, so EVERY
-- insert failed ("null value in column id"). That is why the audit log was
-- always empty. Attach an auto-increment sequence.

CREATE SEQUENCE IF NOT EXISTS daily_audit_log_id_seq;
ALTER TABLE public.daily_audit_log ALTER COLUMN id SET DEFAULT nextval('daily_audit_log_id_seq');
ALTER SEQUENCE daily_audit_log_id_seq OWNED BY public.daily_audit_log.id;
SELECT setval('daily_audit_log_id_seq', COALESCE((SELECT MAX(id) FROM public.daily_audit_log), 0) + 1, false);
