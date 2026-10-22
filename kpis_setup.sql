-- ============================================================
-- Masia Group · Dashboard — Pestaña "KPIs · Canales"
-- Crea SOLO tablas nuevas. No modifica ninguna tabla existente.
-- Ejecutar UNA vez en: Supabase -> SQL Editor -> New query -> Run
-- (Requiere que supabase_setup.sql ya esté corrido: usa is_admin()).
-- ============================================================

-- 1) VENTAS Y METAS por mes · país · empresa · canal (USD netos) -----
--    Se llena con el botón "Cargar ventas y metas" de la pestaña,
--    o más adelante desde n8n (con la service_role, que salta RLS).
create table if not exists public.kpi_ventas (
  anio         integer not null,
  mes          integer not null check (mes between 1 and 12),
  pais         text    not null,
  empresa      text    not null,
  canal        text    not null,
  facturacion  numeric not null default 0,   -- USD netos
  objetivo     numeric not null default 0,   -- USD
  subido_por   uuid references auth.users(id),
  fecha        timestamptz not null default now(),
  primary key (anio, mes, pais, empresa, canal)
);

-- 2) POLÍTICA 6 FOTOS + 1 VIDEO, ya agregada por tienda --------------
--    Solo se guardan los CONTEOS por país · empresa · canal (no el detalle),
--    para que la página cargue rápido.
create table if not exists public.kpi_medios (
  pais         text    not null,
  empresa      text    not null,
  canal        text    not null,
  medidas      integer not null default 0,   -- publicaciones revisadas
  con_fotos    integer not null default 0,   -- con 6 fotos o más
  con_video    integer not null default 0,   -- con al menos 1 video
  cumplen      integer not null default 0,   -- 6+ fotos Y video
  subido_por   uuid references auth.users(id),
  fecha        timestamptz not null default now(),
  primary key (pais, empresa, canal)
);

-- Sello de quién y cuándo (no se confía en el navegador) -------------
create or replace function public.sello_kpi()
returns trigger language plpgsql as $$
begin new.subido_por := auth.uid(); new.fecha := now(); return new; end; $$;

drop trigger if exists trg_sello_kpi_ventas on public.kpi_ventas;
create trigger trg_sello_kpi_ventas before insert or update on public.kpi_ventas
  for each row execute function public.sello_kpi();

drop trigger if exists trg_sello_kpi_medios on public.kpi_medios;
create trigger trg_sello_kpi_medios before insert or update on public.kpi_medios
  for each row execute function public.sello_kpi();

-- ============================================================
-- ROW LEVEL SECURITY
--  · kpi_ventas: todos leen · SOLO ADMIN escribe (cifras de facturación)
--  · kpi_medios: todos leen · cualquier usuario escribe (como publicaciones)
-- ============================================================
alter table public.kpi_ventas enable row level security;
alter table public.kpi_medios enable row level security;

drop policy if exists p_kv_sel on public.kpi_ventas;
create policy p_kv_sel on public.kpi_ventas for select to authenticated using (true);
drop policy if exists p_kv_ins on public.kpi_ventas;
create policy p_kv_ins on public.kpi_ventas for insert to authenticated with check (public.is_admin());
drop policy if exists p_kv_upd on public.kpi_ventas;
create policy p_kv_upd on public.kpi_ventas for update to authenticated using (public.is_admin()) with check (public.is_admin());
drop policy if exists p_kv_del on public.kpi_ventas;
create policy p_kv_del on public.kpi_ventas for delete to authenticated using (public.is_admin());

drop policy if exists p_km_sel on public.kpi_medios;
create policy p_km_sel on public.kpi_medios for select to authenticated using (true);
drop policy if exists p_km_ins on public.kpi_medios;
create policy p_km_ins on public.kpi_medios for insert to authenticated with check (true);
drop policy if exists p_km_upd on public.kpi_medios;
create policy p_km_upd on public.kpi_medios for update to authenticated using (true) with check (true);
drop policy if exists p_km_del on public.kpi_medios;
create policy p_km_del on public.kpi_medios for delete to authenticated using (true);

-- ============================================================
-- 3) ESTADO MANUAL DE CANALES (botón "＋ Agregar canal" de la pestaña KPIs)
--    Para canales que existen pero no tienen datos cargados, o que aún
--    no están creados. En tiendas propias (Masia Shop, Xstore Shop,
--    Camozzi Shop) la empresa se guarda como '*'.
--    Solo afecta la pestaña KPIs · Canales (no toca Cobertura ni PDFs).
-- ============================================================
create table if not exists public.kpi_canales (
  pais         text not null,
  empresa      text not null,
  canal        text not null,
  estado       text not null check (estado in ('activo','pendiente','inactivo')),
  nota         text,
  subido_por   uuid references auth.users(id),
  fecha        timestamptz not null default now(),
  primary key (pais, empresa, canal)
);

drop trigger if exists trg_sello_kpi_canales on public.kpi_canales;
create trigger trg_sello_kpi_canales before insert or update on public.kpi_canales
  for each row execute function public.sello_kpi();

alter table public.kpi_canales enable row level security;
drop policy if exists p_kc_sel on public.kpi_canales;
create policy p_kc_sel on public.kpi_canales for select to authenticated using (true);
drop policy if exists p_kc_ins on public.kpi_canales;
create policy p_kc_ins on public.kpi_canales for insert to authenticated with check (public.is_admin());
drop policy if exists p_kc_upd on public.kpi_canales;
create policy p_kc_upd on public.kpi_canales for update to authenticated using (public.is_admin()) with check (public.is_admin());
drop policy if exists p_kc_del on public.kpi_canales;
create policy p_kc_del on public.kpi_canales for delete to authenticated using (public.is_admin());
