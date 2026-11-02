BEGIN;

ALTER TABLE public.parties
  ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT TRUE;

UPDATE public.parties
SET is_active = TRUE
WHERE is_active IS NULL;

CREATE INDEX IF NOT EXISTS parties_active_kind_name_idx
  ON public.parties(kind, name)
  WHERE is_active = TRUE;

ALTER TABLE public.entries
  ADD COLUMN IF NOT EXISTS vehicle_type VARCHAR(80);

DROP TRIGGER IF EXISTS entries_lock_after_pod_received ON public.entries;

UPDATE public.entries
SET vehicle_type = 'Not recorded'
WHERE direction = 'outward'
  AND (
    NULLIF(BTRIM(vehicle_type), '') IS NULL
    OR vehicle_type NOT IN ('17FT', '32FT', '14FT', 'TATA Ace/Champion', 'Pickup/Bolero', '20FT', '22FT', '24FT', '12FT', 'Auto', 'Bike', 'E-riskhaw', 'Not recorded')
  );

ALTER TABLE public.entries
  DROP CONSTRAINT IF EXISTS entries_outward_vehicle_type_required;

ALTER TABLE public.entries
  ADD CONSTRAINT entries_outward_vehicle_type_required CHECK (
    (direction = 'outward' AND vehicle_type IN ('17FT', '32FT', '14FT', 'TATA Ace/Champion', 'Pickup/Bolero', '20FT', '22FT', '24FT', '12FT', 'Auto', 'Bike', 'E-riskhaw', 'Not recorded'))
    OR direction <> 'outward'
  );

CREATE OR REPLACE FUNCTION public.prevent_received_pod_entry_update()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF OLD.direction = 'outward' AND OLD.entry_type = 'material' AND OLD.pod_received IS TRUE THEN
    RAISE EXCEPTION 'Outward entry is locked because POD is already received.' USING ERRCODE = '55000';
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER entries_lock_after_pod_received
BEFORE UPDATE ON public.entries
FOR EACH ROW
EXECUTE FUNCTION public.prevent_received_pod_entry_update();

COMMIT;

