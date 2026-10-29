-- PHUOTTHU / DEV-09.7D - GPS checkpoint attendance (Supabase)
-- Prerequisite: DEV-09.7A tables and Group Travel v2 live location schema.
-- Execute as DB administrator. Idempotent. Never run 001_core_schema.sql again.
-- GPS is heuristic from phone-supplied positions, not cryptographic proof of presence.
BEGIN;

DO $preflight$
DECLARE missing text;
BEGIN
  IF to_regclass('public.trip_checkpoints') IS NULL
    OR to_regclass('public.trip_checkpoint_arrivals') IS NULL
    OR to_regclass('public.trip_live_locations') IS NULL
    OR to_regclass('public.trip_members') IS NULL THEN
    RAISE EXCEPTION 'Run previous Group Travel and DEV-09.7A migrations first.';
  END IF;
  SELECT string_agg(required.column_name, ', ')
  INTO missing
  FROM (
    VALUES ('trip_id'), ('user_id'), ('latitude'), ('longitude'),
           ('accuracy_m'), ('speed_mps'), ('recorded_at')
  ) AS required(column_name)
  WHERE NOT EXISTS (
    SELECT 1 FROM information_schema.columns c
    WHERE c.table_schema = 'public'
      AND c.table_name = 'trip_live_locations'
      AND c.column_name = required.column_name
  );
  IF missing IS NOT NULL THEN
    RAISE EXCEPTION 'Missing columns in trip_live_locations: %', missing;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'trip_members'
      AND column_name = 'location_sharing'
  ) THEN
    RAISE EXCEPTION 'Expected Group Travel v2 trip_members.location_sharing.';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='trip_members'
      AND column_name='status'
  ) THEN
    RAISE EXCEPTION 'Expected Group Travel v2 trip_members.status.';
  END IF;
END;
$preflight$;

CREATE OR REPLACE FUNCTION public.phuotthu_auto_checkpoint_arrival()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $fn$
DECLARE
  cp record;
  distance_m double precision;
  accuracy_m double precision;
  earth_radius_m constant double precision := 6371000.0;
  delta_lat double precision;
  delta_lon double precision;
  a double precision;
BEGIN
  -- Only the signed-in rider's own location update is eligible.
  -- Do not process forged row changes or server changes without a user token.
  IF auth.uid() IS NULL OR NEW.user_id IS DISTINCT FROM auth.uid() THEN
    RETURN NEW;
  END IF;

  -- Reject old / future / malformed fixes. GPS accuracy must be known.
  IF NEW.recorded_at IS NULL
    OR NEW.recorded_at < now() - interval '90 seconds'
    OR NEW.recorded_at > now() + interval '15 seconds'
    OR NEW.latitude IS NULL OR NEW.longitude IS NULL
    OR NOT (NEW.latitude BETWEEN -90 AND 90)
    OR NOT (NEW.longitude BETWEEN -180 AND 180)
    OR NEW.accuracy_m IS NULL OR NEW.accuracy_m < 0
    OR NEW.accuracy_m > 60
    OR (NEW.speed_mps IS NOT NULL AND NEW.speed_mps > 12)
  THEN
    RETURN NEW;
  END IF;

  -- Sharing must be opted-in AND membership currently active.
  IF NOT EXISTS (
    SELECT 1 FROM public.trip_members m
    WHERE m.trip_id = NEW.trip_id AND m.user_id = NEW.user_id
      AND m.status = 'active' AND m.location_sharing IS TRUE
  ) THEN
    RETURN NEW;
  END IF;

  accuracy_m := NEW.accuracy_m;
  FOR cp IN
    SELECT id, latitude, longitude, radius_m
    FROM public.trip_checkpoints
    WHERE trip_id = NEW.trip_id AND auto_arrival_enabled IS TRUE
  LOOP
    -- Great-circle distance (Haversine), meters; numeric clamping avoids NaN.
    delta_lat := radians(NEW.latitude - cp.latitude);
    delta_lon := radians(NEW.longitude - cp.longitude);
    a := power(sin(delta_lat / 2), 2)
       + cos(radians(cp.latitude)) * cos(radians(NEW.latitude))
       * power(sin(delta_lon / 2), 2);
    distance_m := 2 * earth_radius_m * asin(sqrt(least(1.0, greatest(0.0, a))));

    -- Conservative criterion: the uncertainty radius must fit inside the checkpoint.
    IF accuracy_m <= least(60.0, cp.radius_m / 2.0)
       AND distance_m + accuracy_m <= cp.radius_m THEN
      INSERT INTO public.trip_checkpoint_arrivals (
        checkpoint_id, user_id, arrival_method, distance_m, gps_accuracy_m
      ) VALUES (
        cp.id, NEW.user_id, 'gps', round(distance_m::numeric, 2),
        round(accuracy_m::numeric, 2)
      ) ON CONFLICT (checkpoint_id, user_id) DO NOTHING;
    END IF;
  END LOOP;
  RETURN NEW;
END;
$fn$;

REVOKE ALL ON FUNCTION public.phuotthu_auto_checkpoint_arrival() FROM PUBLIC, anon, authenticated;
DROP TRIGGER IF EXISTS phuotthu_auto_checkpoint_arrival_trigger
ON public.trip_live_locations;
CREATE TRIGGER phuotthu_auto_checkpoint_arrival_trigger
AFTER INSERT OR UPDATE OF latitude, longitude, accuracy_m, speed_mps, recorded_at
ON public.trip_live_locations
FOR EACH ROW
EXECUTE FUNCTION public.phuotthu_auto_checkpoint_arrival();

COMMENT ON FUNCTION public.phuotthu_auto_checkpoint_arrival() IS
 'Auto arrival from fresh opted-in GPS, accuracy-aware; idempotent. Requires active membership.';
COMMIT;
