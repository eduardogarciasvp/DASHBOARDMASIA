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

-- ============================================================
-- 4) INVENTARIO MANUAL (botón "Cargar inventario" en Operaciones ›
--    Datos del Dashboard), mientras se conecta el ERP.
--    Una fila por SKU; cada carga reemplaza los países que trae.
--    El dashboard lee solo el resumen por país · empresa.
-- ============================================================
create table if not exists public.kpi_inventario (
  id           bigint generated always as identity primary key,
  pais         text    not null,
  empresa      text    not null default '*',
  sku          text    not null,
  descripcion  text,
  stock        numeric not null default 0,
  subido_por   uuid references auth.users(id),
  fecha        timestamptz not null default now()
);
create index if not exists kpi_inventario_pais_idx on public.kpi_inventario (pais);

drop trigger if exists trg_sello_kpi_inventario on public.kpi_inventario;
create trigger trg_sello_kpi_inventario before insert or update on public.kpi_inventario
  for each row execute function public.sello_kpi();

alter table public.kpi_inventario enable row level security;
drop policy if exists p_ki_sel on public.kpi_inventario;
create policy p_ki_sel on public.kpi_inventario for select to authenticated using (true);
drop policy if exists p_ki_ins on public.kpi_inventario;
create policy p_ki_ins on public.kpi_inventario for insert to authenticated with check (true);
drop policy if exists p_ki_upd on public.kpi_inventario;
create policy p_ki_upd on public.kpi_inventario for update to authenticated using (true) with check (true);
drop policy if exists p_ki_del on public.kpi_inventario;
create policy p_ki_del on public.kpi_inventario for delete to authenticated using (true);

create or replace view public.kpi_inventario_resumen with (security_invoker = true) as
  select pais, empresa,
         count(*)::int                                        as skus,
         (count(*) filter (where stock > 0))::int             as skus_stock,
         coalesce(sum(stock) filter (where stock > 0), 0)     as unidades,
         max(fecha)                                           as fecha
  from public.kpi_inventario
  group by pais, empresa;
grant select on public.kpi_inventario_resumen to authenticated;

-- ============================================================
-- 5) STOCK vs PUBLICACIONES (sección del Dashboard)
--    Cruza inventario → matriz (SKU completo) → títulos publicados.
-- ============================================================
create index if not exists idx_mt_sku_norm on public.matriz_titulos (upper(btrim(sku)));
create index if not exists idx_pt_tienda_tit on public.pub_titulos (pais, empresa, canal, titulo_norm);

-- Por SKU con stock y tienda: posibles (productos de la matriz con ese SKU, con precio, en el
-- idioma del país), creadas (ya publicadas, misma regla que la validación), con_sku (publicaciones
-- de la tienda con ese SKU aunque no sigan la matriz) y validada (la tienda tiene títulos cargados).
create or replace function public.stock_vs_publicaciones(p_pais text default null)
returns table(pais text, empresa text, canal text, sku text, stock numeric,
              posibles bigint, creadas bigint, con_sku bigint, validada boolean)
language sql stable set search_path = public as $$
  with inv as (
    select i.pais, i.empresa as inv_emp, upper(btrim(i.sku)) as sku, sum(i.stock) as stock
    from kpi_inventario i
    where i.stock > 0 and (p_pais is null or i.pais = p_pais)
    group by 1, 2, 3
  ), tiendas as (
    select distinct t.pais, t.empresa, t.canal
    from (select c.pais, c.empresa, c.canal from cobertura c
          union select p.pais, p.empresa, p.canal from publicaciones p) t
    where p_pais is null or t.pais = p_pais
  ), mz as (
    select t.pais, t.empresa, t.canal, inv.sku, inv.stock, m.titulo_norm,
           coalesce(m.fila, m.titulo_norm) as fila
    from inv
    join tiendas t on t.pais = inv.pais and (inv.inv_emp = '*' or inv.inv_emp = t.empresa)
    join matriz_titulos m on m.empresa = t.empresa and upper(btrim(m.sku)) = inv.sku
         and m.tiene_precio = 'SI'
         and (m.idioma is null or m.idioma = case when t.pais = 'Estados Unidos' then 'EN' else 'ES' end)
  ), agg as (
    select mz.pais, mz.empresa, mz.canal, mz.sku, max(mz.stock) as stock,
           count(distinct mz.fila) as posibles,
           count(distinct mz.fila) filter (where exists (
             select 1 from pub_titulos p
             where p.pais = mz.pais and p.empresa = mz.empresa and p.canal = mz.canal
               and p.titulo_norm = mz.titulo_norm)) as creadas
    from mz group by 1, 2, 3, 4
  )
  select a.pais, a.empresa, a.canal, a.sku, a.stock, a.posibles, a.creadas,
         (select count(*) from pub_titulos p
           where p.pais = a.pais and p.empresa = a.empresa and p.canal = a.canal
             and (upper(btrim(p.sku)) = a.sku
                  or (a.canal ~* 'amazon' and upper(btrim(p.sku)) like a.sku || '-%'))) as con_sku,
         exists (select 1 from pub_titulos p
                  where p.pais = a.pais and p.empresa = a.empresa and p.canal = a.canal) as validada
  from agg a;
$$;

-- Títulos de la matriz de un SKU que faltan por publicar en una tienda.
create or replace function public.stock_faltantes(p_pais text, p_empresa text, p_canal text, p_sku text)
returns table(titulo text, sku text)
language sql stable set search_path = public as $$
  select min(m.titulo), max(m.sku)
  from matriz_titulos m
  where m.empresa = p_empresa and upper(btrim(m.sku)) = upper(btrim(p_sku)) and m.tiene_precio = 'SI'
    and (m.idioma is null or m.idioma = case when p_pais = 'Estados Unidos' then 'EN' else 'ES' end)
    and not exists (select 1 from pub_titulos p
                    where p.pais = p_pais and p.empresa = p_empresa and p.canal = p_canal
                      and p.titulo_norm = m.titulo_norm)
  group by coalesce(m.fila, m.titulo_norm)
  order by 1;
$$;
grant execute on function public.stock_vs_publicaciones(text) to authenticated;
grant execute on function public.stock_faltantes(text, text, text, text) to authenticated;
