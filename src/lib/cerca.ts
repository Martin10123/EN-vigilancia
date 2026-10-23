import { rpc } from '@/lib/api'
import { esFallaDeRed } from '@/lib/domain'
import { ubicacionActual } from '@/lib/geo'

type Cerca = { aceptado: boolean; metros: number; radio_m: number }

export async function exigirCercania() {
  const punto = await ubicacionActual()
  try {
    const cerca = await rpc<Cerca>('estoy_cerca', { lat: punto.lat, lng: punto.lng })
    if (!cerca.aceptado) {
      throw new Error(`Estás a ${cerca.metros} m. Hay que estar a ${cerca.radio_m} m o menos.`)
    }
  } catch (error) {
    if (!esFallaDeRed(error)) throw error
  }
  return punto
}
