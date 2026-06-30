# Dashboard de cumplimiento · Masia Group

Panel multiusuario de cumplimiento de publicaciones e-commerce.
**Front-end estático** (Vercel) + **Supabase** (base de datos, login y permisos).
Sin backend que mantener: el navegador habla directo con Supabase y las
políticas RLS imponen quién puede hacer qué.

## Reglas de acceso (las impone la base, no el código)
- **Solo el admin** carga las **matrices** (una por empresa).
- **Cualquier usuario** carga **publicaciones** (así se cubren vacaciones).
- **Todos leen todo.** La asignación de países es solo el *filtro por defecto*.

---

## Archivos
| Archivo | Qué es |
|---|---|
| `index.html` | El dashboard (3 pestañas + login). |
| `config.js` | URL + anon key de tu proyecto Supabase. |
| `supabase_setup.sql` | Tablas + políticas RLS + triggers. Se corre una vez. |

---

## Montaje (≈15 min)

### 1. Crear el proyecto Supabase
En [supabase.com](https://supabase.com) crea un proyecto nuevo. Anota la contraseña.

### 2. Crear tablas y políticas
Supabase → **SQL Editor** → **New query** → pega todo `supabase_setup.sql` → **Run**.

### 3. Crear los 3 usuarios
Supabase → **Authentication → Users → Add user** (correo + contraseña, uno por persona).
Marca *Auto Confirm User* para que puedan entrar de una vez.

### 4. Fijar rol y países
SQL Editor de nuevo, cambiando los correos. Usa **exactamente** estos nombres de país:
`México · Colombia · Estados Unidos · Brasil · Venezuela · España`.

```sql
update public.profiles set rol='admin', paises='{España,Brasil}'           where email='TU_CORREO_ADMIN';
update public.profiles set                paises='{Venezuela,Colombia}'    where email='ASISTENTE_1';
update public.profiles set                paises='{México,Estados Unidos}' where email='ASISTENTE_2';
```

### 5. Conectar `config.js`
Supabase → **Project Settings → API**. Copia **Project URL** y **anon public key** a `config.js`:

```js
window.SUPA_URL  = "https://xxxx.supabase.co";
window.SUPA_ANON = "eyJ...";   // anon key (PÚBLICA por diseño; nunca la service_role)
```

### 6. Desplegar en Vercel

**Opción A · GitHub (recomendada, queda montado con redeploy y rollback)**
1. Sube esta carpeta a un repo en GitHub.
2. En Vercel → **New Project** → importa el repo → **Deploy**.
   Es un sitio estático: sin build, sin configuración extra.
3. Cada `git push` redespliega solo; los deploys viejos quedan para rollback de un clic.

**Opción B · CLI (sin Git)**
```bash
npm i -g vercel
vercel          # preview
vercel --prod   # producción (mismo proyecto y URL cada vez)
```

Listo: cada quien entra en la URL de Vercel con su correo y contraseña.

---

## Cómo se usa
1. **Admin** entra → *Cargar matriz* (una por empresa) → cuenta publicaciones (con precio) y SKUs por empresa.
2. **Admin** → pestaña **Cobertura** → define País · Empresa · Canal. Los denominadores se llenan solos.
   *La Masia Shop va como una fila por empresa: el total del país las suma.*
3. **Usuarios** → *Cargar publicaciones* (export por tienda) → se guarda lo real.
4. Todos ven el cumplimiento cruzado. Cada quien arranca filtrado por sus países, pero puede quitar el filtro.

---

## Seguridad
- La **anon key es pública**: puede ir en el repo. La protección real son las **políticas RLS**, no el secreto.
- **Nunca** pongas la `service_role` key en `config.js` ni en el navegador.
- Aunque se oculten botones por rol, el candado de verdad está en la base: un usuario no-admin no puede escribir en `matriz` ni aunque manipule el navegador.

## Notas
- La matriz se procesa en el navegador y solo se guardan los **conteos** por empresa (4 filas), no el Excel.
- Si cambias de empresas/canales/países, ajusta las listas al inicio del `<script>` en `index.html`
  (`ORD_PAIS`, `CANALES`, `EMPRESAS`, `FLAGS`).
