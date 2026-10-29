-- Read-only verification; run after 006. Does not require or modify trip data.
SELECT
  (to_regclass('public.trip_live_locations') IS NOT NULL) AS live_locations_exists,
  (to_regclass('public.trip_checkpoints') IS NOT NULL) AS checkpoints_exists,
  (to_regprocedure('public.phuotthu_auto_checkpoint_arrival()') IS NOT NULL) AS function_exists,
  EXISTS (
    SELECT 1 FROM pg_trigger t
    JOIN pg_class c ON c.oid = t.tgrelid
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname='public' AND c.relname='trip_live_locations'
      AND t.tgname='phuotthu_auto_checkpoint_arrival_trigger'
      AND t.tgenabled <> 'D'
  ) AS trigger_enabled;

SELECT arrival_method, count(*) AS attendance_count
FROM public.trip_checkpoint_arrivals
GROUP BY arrival_method ORDER BY arrival_method;
