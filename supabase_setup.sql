-- ============================================================
-- Masia Group · Dashboard de cumplimiento — Setup de Supabase
-- Ejecutar UNA vez en: Supabase  ->  SQL Editor  ->  New query  ->  Run
-- ============================================================

-- 1) PERFILES  (rol + países asignados) ----------------------
create table if not exists public.profiles (
  id      uuid primary key references auth.users(id) on delete cascade,
  email   text,
  rol     text not null default 'user' check (rol in ('admin','user')),
  paises  text[] not null default '{}',
  creado  timestamptz not null default now()
);

-- 2) MATRIZ  (deber ser, ya agregada por empresa) ------------
create table if not exists public.matriz (
  empresa         text primary key,
  pub             integer not null default 0,   -- publicaciones con precio
  sku             integer not null default 0,   -- SKUs físicos distintos
  actualizado_por uuid references auth.users(id),
  fecha           timestamptz not null default now()
);

-- 3) COBERTURA  (qué empresa/canal opera en qué país) --------
create table if not exists public.cobertura (
  id      bigint generated always as identity primary key,
  pais    text not null,
  empresa text not null,
  canal   text not null,
  unique (pais, empresa, canal)
);

-- 4) PUBLICACIONES  (lo real subido por cada canal) ----------
create table if not exists public.publicaciones (
  id          bigint generated always as identity primary key,
  pais        text not null,
  empresa     text not null,
  canal       text not null,
  sku_pb      integer not null default 0,   -- SKUs únicos publicados
  pub         integer not null default 0,   -- publicaciones (listings)
  subido_por  uuid references auth.users(id),
  fecha       timestamptz not null default now(),
  unique (pais, empresa, canal)
);

-- ============================================================
-- Helper: ¿el usuario actual es admin?
-- SECURITY DEFINER para leer profiles sin recursión de RLS.
-- ============================================================
create or replace function public.is_admin()
returns boolean language sql security definer stable
set search_path = public as $$
  select exists (select 1 from public.profiles
                 where id = auth.uid() and rol = 'admin');
$$;
grant execute on function public.is_admin() to authenticated;

-- ============================================================
-- Crea el perfil automáticamente al crear un usuario (rol 'user').
-- Tú luego marcas tu cuenta como admin (ver el final del archivo).
-- ============================================================
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer
set search_path = public as $$
begin
  insert into public.profiles (id, email)
  values (new.id, new.email)
  on conflict (id) do nothing;
  return new;
end; $$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Sella quién y cuándo, sin confiar en el cliente ------------
create or replace function public.sello_pub()
returns trigger language plpgsql as $$
begin new.subido_por := auth.uid(); new.fecha := now(); return new; end; $$;
drop trigger if exists trg_sello_pub on public.publicaciones;
create trigger trg_sello_pub before insert or update on public.publicaciones
  for each row execute function public.sello_pub();

create or replace function public.sello_mat()
returns trigger language plpgsql as $$
begin new.actualizado_por := auth.uid(); new.fecha := now(); return new; end; $$;
drop trigger if exists trg_sello_mat on public.matriz;
create trigger trg_sello_mat before insert or update on public.matriz
  for each row execute function public.sello_mat();

-- ============================================================
-- ROW LEVEL SECURITY  (aquí vive tu regla, no en el código)
-- ============================================================
alter table public.profiles      enable row level security;
alter table public.matriz        enable row level security;
alter table public.cobertura     enable row level security;
alter table public.publicaciones enable row level security;

-- PROFILES: cada quien ve su perfil; admin ve todos; solo admin edita
drop policy if exists p_prof_sel on public.profiles;
create policy p_prof_sel on public.profiles for select to authenticated
  using (id = auth.uid() or public.is_admin());
drop policy if exists p_prof_upd on public.profiles;
create policy p_prof_upd on public.profiles for update to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- MATRIZ: todos leen ·  S O L O   A D M I N   escribe   <<< tu regla dura
drop policy if exists p_mat_sel on public.matriz;
create policy p_mat_sel on public.matriz for select to authenticated using (true);
drop policy if exists p_mat_ins on public.matriz;
create policy p_mat_ins on public.matriz for insert to authenticated with check (public.is_admin());
drop policy if exists p_mat_upd on public.matriz;
create policy p_mat_upd on public.matriz for update to authenticated using (public.is_admin()) with check (public.is_admin());
drop policy if exists p_mat_del on public.matriz;
create policy p_mat_del on public.matriz for delete to authenticated using (public.is_admin());

-- COBERTURA: todos leen; solo admin edita (es estructural)
drop policy if exists p_cob_sel on public.cobertura;
create policy p_cob_sel on public.cobertura for select to authenticated using (true);
drop policy if exists p_cob_ins on public.cobertura;
create policy p_cob_ins on public.cobertura for insert to authenticated with check (public.is_admin());
drop policy if exists p_cob_upd on public.cobertura;
create policy p_cob_upd on public.cobertura for update to authenticated using (public.is_admin()) with check (public.is_admin());
drop policy if exists p_cob_del on public.cobertura;
create policy p_cob_del on public.cobertura for delete to authenticated using (public.is_admin());

-- PUBLICACIONES: todos leen; CUALQUIER usuario escribe (cubre vacaciones)
drop policy if exists p_pub_sel on public.publicaciones;
create policy p_pub_sel on public.publicaciones for select to authenticated using (true);
drop policy if exists p_pub_ins on public.publicaciones;
create policy p_pub_ins on public.publicaciones for insert to authenticated with check (true);
drop policy if exists p_pub_upd on public.publicaciones;
create policy p_pub_upd on public.publicaciones for update to authenticated using (true) with check (true);
drop policy if exists p_pub_del on public.publicaciones;
create policy p_pub_del on public.publicaciones for delete to authenticated using (true);

-- ============================================================
-- DESPUÉS de crear los 3 usuarios en Authentication > Users,
-- corre estas líneas (cambia los correos) para fijar rol y países.
-- La asignación de países es solo el FILTRO POR DEFECTO: todos
-- pueden ver y cargar cualquier país (no es un candado).
-- ------------------------------------------------------------
-- update public.profiles set rol='admin', paises='{España,Brasil}'        where email='TU_CORREO_ADMIN';
-- update public.profiles set                paises='{Venezuela,Colombia}' where email='ASISTENTE_1';
-- update public.profiles set                paises='{México,Estados Unidos}' where email='ASISTENTE_2';
-- ============================================================
