import { del, get, keys, set, createStore } from 'idb-keyval'
import { ref } from 'vue'
import { anotar } from '@/lib/bitacora'
import { esFallaDeRed } from '@/lib/domain'
import { blobABase64 } from '@/lib/media'
import { supabase } from '@/lib/supabase'

const store = createStore('vigilancia', 'cola')

export type ClaseEvento = 'marcacion' | 'escaneo' | 'incidente'

export type EventoLocal = {
  id: string
  clase: ClaseEvento
  token: string
  lat: number
  lng: number
  foto: Blob | null
  tipo: string
  descripcion: string
  guardadoEn: string
  error?: string
}

export const pendientes = ref(0)

export async function refrescarConteo() {
  pendientes.value = (await keys(store)).length
}

export async function listarCola() {
  const ids = await keys<string>(store)
  const filas = await Promise.all(ids.map(async (id) => (await get<EventoLocal>(id, store)) ?? null))
  return filas.filter((fila): fila is EventoLocal => fila != null).sort((a, b) => a.guardadoEn.localeCompare(b.guardadoEn))
}

export async function encolar(evento: Omit<EventoLocal, 'id' | 'guardadoEn' | 'error'>) {
  const fila: EventoLocal = {
    ...evento,
    id: crypto.randomUUID(),
    guardadoEn: new Date().toISOString(),
  }
  await set(fila.id, fila, store)
  await refrescarConteo()
  return fila
}

async function publicar(evento: EventoLocal, offline: boolean) {
  const { data, error } = await supabase.functions.invoke('registrar-evento', {
    body: {
      clase: evento.clase,
      token: evento.token,
      lat: evento.lat,
      lng: evento.lng,
      offline,
      tipo: evento.tipo,
      descripcion: evento.descripcion,
      foto: evento.foto ? await blobABase64(evento.foto) : '',
    },
  })
  if (error) {
    anotar('No se pudo enviar el registro.', error.message, evento.clase)
    throw error
  }
  if (data?.error) {
    anotar(String(data.error), evento.clase, evento.clase)
    throw new Error(data.error)
  }
  return data as { ok: boolean; punto?: string | null }
}

export async function enviarEvento(evento: Omit<EventoLocal, 'id' | 'guardadoEn' | 'error'>) {
  if (!navigator.onLine) {
    await encolar(evento)
    return { encolado: true as const }
  }
  const temporal: EventoLocal = { ...evento, id: 'tmp', guardadoEn: new Date().toISOString() }
  try {
    const data = await publicar(temporal, false)
    return { encolado: false as const, punto: data.punto }
  } catch (error) {
    if (!esFallaDeRed(error)) throw error
    await encolar(evento)
    return { encolado: true as const }
  }
}

export async function sincronizar() {
  const filas = await listarCola()
  for (const fila of filas) {
    try {
      await publicar(fila, true)
      await del(fila.id, store)
    } catch (error) {
      if (esFallaDeRed(error)) break
      await set(fila.id, { ...fila, error: error instanceof Error ? error.message : 'No se pudo sincronizar.' }, store)
    }
  }
  await refrescarConteo()
}
