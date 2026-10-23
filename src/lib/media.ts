import { supabase } from '@/lib/supabase'

export async function comprimirImagen(archivo: Blob, maximo = 1280, calidad = 0.72) {
  const bitmap = await createImageBitmap(archivo)
  const escala = Math.min(1, maximo / Math.max(bitmap.width, bitmap.height))
  const lienzo = document.createElement('canvas')
  lienzo.width = Math.max(1, Math.round(bitmap.width * escala))
  lienzo.height = Math.max(1, Math.round(bitmap.height * escala))
  const contexto = lienzo.getContext('2d')
  if (!contexto) throw new Error('No se pudo preparar la foto.')
  contexto.drawImage(bitmap, 0, 0, lienzo.width, lienzo.height)
  bitmap.close()
  const blob = await new Promise<Blob | null>((resolve) => lienzo.toBlob(resolve, 'image/jpeg', calidad))
  if (!blob) throw new Error('No se pudo preparar la foto.')
  return blob
}

export async function blobABase64(blob: Blob) {
  const bytes = new Uint8Array(await blob.arrayBuffer())
  let binario = ''
  const bloque = 0x8000
  for (let i = 0; i < bytes.length; i += bloque) {
    binario += String.fromCharCode(...bytes.subarray(i, i + bloque))
  }
  return btoa(binario)
}

export async function urlFirmada(path: string) {
  const { data, error } = await supabase.storage.from('evidencias').createSignedUrl(path, 60 * 10)
  if (error) throw error
  return data.signedUrl
}
