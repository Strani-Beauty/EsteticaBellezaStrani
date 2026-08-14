-- Diagnóstico temporal: aísla si profiles_especialista_cita causa la recursión.
DROP POLICY IF EXISTS "profiles_especialista_cita" ON public.profiles;
