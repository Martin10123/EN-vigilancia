import { createClient } from 'npm:@supabase/supabase-js@2'

const PERMITIDOS = ['administrador', 'vigilante', 'residente']

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json', ...cors },
  })

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors })
  if (req.method !== 'POST') return json({ error: 'Método no permitido.' }, 405)

  const url = Deno.env.get('SUPABASE_URL')
  const anon = Deno.env.get('SUPABASE_ANON_KEY')
  const service = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
  const autorizacion = req.headers.get('Authorization')
  if (!url || !anon || !service || !autorizacion) return json({ error: 'Falta la configuración del servidor.' })

  const usuario = createClient(url, anon, { global: { headers: { Authorization: autorizacion } } })
  const { data: sesion, error: sesionError } = await usuario.auth.getUser()
  if (sesionError || !sesion.user) return json({ error: 'Sesión inválida.' })

  const admin = createClient(url, service)
  const { data: perfil } = await admin
    .from('perfiles')
    .select('id, perfil_roles(rol_id)')
    .eq('auth_user_id', sesion.user.id)
    .single()

  const rolesActuales = (perfil?.perfil_roles ?? []).map((rol: { rol_id: string }) => rol.rol_id)
  if (!perfil || !rolesActuales.includes('administrador')) return json({ error: 'Solo un administrador puede crear usuarios.' })

  const body = await req.json()
  const email = String(body.email ?? '').trim().toLowerCase()
  const password = String(body.password ?? '')
  const nombre = String(body.nombre ?? '').trim()
  const telefono = String(body.telefono ?? '').trim()
  const roles = (Array.isArray(body.roles) ? body.roles : []).map(String).filter((rol: string) => PERMITIDOS.includes(rol))
  if (!email.includes('@') || password.length < 6 || nombre.length < 3 || roles.length === 0) {
    return json({ error: 'Completa nombre, correo, contraseña de 6 caracteres y al menos un rol.' })
  }

  await admin.from('invitaciones').delete().eq('email', email).eq('usada', false)
  const { error: invError } = await admin.from('invitaciones').insert({ email, creada_por: perfil.id })
  if (invError) return json({ error: 'No se pudo preparar la invitación.' })

  const { data: creado, error: crearError } = await admin.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
    user_metadata: { nombre },
  })

  if (crearError || !creado.user) {
    await admin.from('invitaciones').delete().eq('email', email).eq('usada', false)
    return json({ error: 'No se pudo crear el usuario. Revisa el correo y la contraseña.' })
  }

  const { data: nuevo } = await admin.from('perfiles').select('id').eq('auth_user_id', creado.user.id).single()
  if (!nuevo) return json({ error: 'El usuario se creó, pero no apareció su perfil.' })

  const comoAdmin = createClient(url, anon, { global: { headers: { Authorization: autorizacion } } })
  const { error: accesoError } = await comoAdmin.rpc('guardar_acceso', {
    perfil_id: nuevo.id,
    roles,
    activo: true,
    telefono,
  })
  if (accesoError) return json({ error: accesoError.message })

  await admin.from('perfiles').update({ nombre }).eq('id', nuevo.id)
  return json({ ok: true })
})
