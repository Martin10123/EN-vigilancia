import { createClient } from 'npm:@supabase/supabase-js@2'

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  })

function bytesDeBase64(valor: string) {
  const limpio = valor.includes(',') ? (valor.split(',')[1] ?? '') : valor
  const bin = atob(limpio)
  const bytes = new Uint8Array(bin.length)
  for (let i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i)
  return bytes
}

async function sha256(bytes: Uint8Array) {
  const digest = await crypto.subtle.digest('SHA-256', bytes)
  return [...new Uint8Array(digest)].map((byte) => byte.toString(16).padStart(2, '0')).join('')
}

Deno.serve(async (req) => {
  if (req.method !== 'POST') return json({ error: 'Método no permitido.' }, 405)

  const url = Deno.env.get('SUPABASE_URL')
  const anon = Deno.env.get('SUPABASE_ANON_KEY')
  const service = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
  const autorizacion = req.headers.get('Authorization')
  if (!url || !anon || !service || !autorizacion) return json({ error: 'Falta la configuración del servidor.' })

  const usuario = createClient(url, anon, { global: { headers: { Authorization: autorizacion } } })
  const { data: sesion, error: sesionError } = await usuario.auth.getUser()
  if (sesionError || !sesion.user) return json({ error: 'Sesión inválida.' })

  const body = await req.json()
  const admin = createClient(url, service)
  const { data: perfil } = await admin.from('perfiles').select('id').eq('auth_user_id', sesion.user.id).single()
  if (!perfil) return json({ error: 'No se encontró el perfil.' })

  const fotoTexto = String(body.foto ?? '')
  let path: string | null = null
  let hash: string | null = null
  if (fotoTexto.length > 0) {
    if (fotoTexto.length > 2_500_000) return json({ error: 'La foto es demasiado pesada.' })
    const bytes = bytesDeBase64(fotoTexto)
    if (bytes.byteLength < 32) return json({ error: 'La foto no llegó bien.' })
    hash = await sha256(bytes)
    path = `${perfil.id}/${crypto.randomUUID()}.jpg`
    const subida = await admin.storage.from('evidencias').upload(path, bytes, {
      contentType: 'image/jpeg',
      upsert: false,
    })
    if (subida.error) return json({ error: 'No se pudo guardar la foto.' })
  }

  const { data, error } = await admin.rpc('registrar_evento', {
    p_auth_user_id: sesion.user.id,
    p_clase: String(body.clase ?? ''),
    p_token: body.token ? String(body.token) : null,
    p_lat: Number(body.lat),
    p_lng: Number(body.lng),
    p_path: path,
    p_hash: hash,
    p_offline: Boolean(body.offline),
    p_tipo: body.tipo ? String(body.tipo) : null,
    p_descripcion: body.descripcion ? String(body.descripcion) : null,
  })

  if (error || data?.ok === false) {
    if (path) await admin.storage.from('evidencias').remove([path])
    return json({ error: data?.error || error?.message || 'No se pudo registrar.' })
  }

  return json({ ok: true, punto: data?.punto ?? null })
})
