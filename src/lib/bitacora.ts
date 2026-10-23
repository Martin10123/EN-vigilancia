import { supabase } from '@/lib/supabase'
import { useSessionStore } from '@/stores/session'

export function anotar(mensaje: string, detalle?: string, origen = 'cliente') {
  const texto = mensaje.trim().slice(0, 500)
  if (!texto) return
  let perfilId: string | null = null
  try {
    perfilId = useSessionStore().perfil?.id ?? null
  } catch {
    perfilId = null
  }
  void supabase.from('bitacora').insert({
    perfil_id: perfilId,
    nivel: 'error',
    origen: origen.slice(0, 40),
    mensaje: texto,
    ruta: location.pathname.slice(0, 200),
    detalle: detalle?.trim().slice(0, 1000) || null,
  })
}
