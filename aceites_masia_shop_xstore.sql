-- ============================================================
-- Masia Group · Dashboard — Exclusión de aceites en la Masia Shop · Xstore
-- Ya aplicado en Supabase (respaldo para reinstalar).
--  · es_aceite(sku): familia de SKU K/M + O (KOA, KOPGRI, KOGWS, KOVP…), sin KOWS/MOWS (separadores de agua).
--  · excluye_aceites(empresa, canal): hoy solo Xstore · Masia Shop (los aceites de la Masia Shop van por Masia Group).
--  · validar_tienda / validar_detalle / stock_vs_publicaciones / stock_faltantes descuentan los aceites en esa tienda.
--    (stock_vs_publicaciones y stock_faltantes: ver kpis_setup.sql parte 5, con el filtro
--     "not (excluye_aceites(t.empresa, t.canal) and es_aceite(...))").
-- Después de cambiar la regla, recalcular: select validar_tienda(pais,'Xstore','Masia Shop') por país.
-- ============================================================
CREATE OR REPLACE FUNCTION public.es_aceite(p_sku text)
 RETURNS boolean LANGUAGE sql IMMUTABLE
AS $function$
  select coalesce(
    (case when position('.' in btrim(p_sku)) > 0 then upper(split_part(btrim(p_sku), '.', 2)) else upper(btrim(p_sku)) end) ~ '^[KM]O'
    and (case when position('.' in btrim(p_sku)) > 0 then upper(split_part(btrim(p_sku), '.', 2)) else upper(btrim(p_sku)) end) !~ '^[KM]OWS',
    false);
$function$;

CREATE OR REPLACE FUNCTION public.excluye_aceites(p_empresa text, p_canal text)
 RETURNS boolean LANGUAGE sql IMMUTABLE
AS $function$ select p_empresa = 'Xstore' and p_canal = 'Masia Shop'; $function$;

create index if not exists idx_mt_emp_aceite on public.matriz_titulos (empresa, public.es_aceite(sku));
grant execute on function public.es_aceite(text) to authenticated;
grant execute on function public.excluye_aceites(text, text) to authenticated;
