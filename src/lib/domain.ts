export const ROLES = [
  { id: 'administrador', nombre: 'Administrador' },
  { id: 'vigilante', nombre: 'Vigilante' },
  { id: 'residente', nombre: 'Residente' },
] as const

export const TIPOS_INCIDENTE = [
  { id: 'novedad', nombre: 'Novedad' },
  { id: 'dano', nombre: 'Daño' },
  { id: 'ingreso', nombre: 'Ingreso no autorizado' },
  { id: 'emergencia', nombre: 'Emergencia' },
  { id: 'otro', nombre: 'Otro' },
] as const

export const ESTADOS: Record<string, string> = {
  administrador: 'Administrador',
  vigilante: 'Vigilante',
  residente: 'Residente',
  marcacion: 'Marcación',
  escaneo: 'Punto de ronda',
  incidente: 'Incidente',
  programado: 'Programado',
  en_curso: 'En curso',
  cerrado: 'Cerrado',
  cancelado: 'Cancelado',
  pendiente: 'Pendiente',
  completa: 'Completa',
  incompleta: 'Incompleta',
  entrada: 'Entrada',
  salida: 'Salida',
  sin_entrada: 'Sin entrada',
  ronda_incompleta: 'Ronda incompleta',
  fuera_radio: 'Fuera del radio',
  novedad: 'Novedad',
  dano: 'Daño',
  ingreso: 'Ingreso no autorizado',
  emergencia: 'Emergencia',
  otro: 'Otro',
  llamada: 'Llamada',
  mensaje: 'Mensaje',
}

export function nombreEstado(estado: string | null | undefined) {
  if (!estado) return '—'
  return ESTADOS[estado] ?? estado
}

export function fechaHora(valor: string | null | undefined) {
  if (!valor) return '—'
  return new Intl.DateTimeFormat('es-CO', {
    timeZone: 'America/Bogota',
    dateStyle: 'short',
    timeStyle: 'short',
  }).format(new Date(valor))
}

export function aLocal(fecha: Date) {
  const pad = (n: number) => String(n).padStart(2, '0')
  return `${fecha.getFullYear()}-${pad(fecha.getMonth() + 1)}-${pad(fecha.getDate())}T${pad(fecha.getHours())}:${pad(fecha.getMinutes())}`
}

export function turnoRapido(horaInicio: number) {
  const inicio = new Date()
  inicio.setHours(horaInicio, 0, 0, 0)
  const fin = new Date(inicio.getTime() + 12 * 60 * 60 * 1000)
  return { inicio: aLocal(inicio), fin: aLocal(fin) }
}

export function mensajeError(error: unknown) {
  const texto =
    error && typeof error === 'object' && 'message' in error && typeof error.message === 'string'
      ? error.message
      : error instanceof Error
        ? error.message
        : 'No se pudo completar la acción.'
  if (texto.includes('Failed to fetch') || texto.includes('NetworkError') || texto.includes('Load failed')) {
    return 'No hay conexión con el servidor.'
  }
  return texto
}

export function esFallaDeRed(error: unknown) {
  const texto = mensajeError(error)
  return !navigator.onLine || texto.includes('No hay conexión')
}

export function referenciaQr(token: string) {
  const payload = token.split('.')[0] ?? ''
  const partes = payload.split('|')
  if (partes.length !== 4 || !partes[0] || !partes[1]) return null
  return { tipo: partes[0], ref: partes[1] }
}

export function telefonoWhatsapp(telefono: string) {
  const digitos = telefono.replace(/\D/g, '')
  if (digitos.length === 10) return `57${digitos}`
  return digitos
}

export function descargarCsv(nombre: string, filas: Record<string, unknown>[]) {
  if (filas.length === 0) return
  const columnas = Object.keys(filas[0] ?? {})
  const lineas = [
    columnas.join(','),
    ...filas.map((fila) =>
      columnas.map((columna) => `"${String(fila[columna] ?? '').replaceAll('"', '""')}"`).join(','),
    ),
  ]
  const blob = new Blob([`\uFEFF${lineas.join('\n')}`], { type: 'text/csv;charset=utf-8' })
  const url = URL.createObjectURL(blob)
  const enlace = document.createElement('a')
  enlace.href = url
  enlace.download = nombre
  enlace.click()
  URL.revokeObjectURL(url)
}
