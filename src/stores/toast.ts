import { ref } from 'vue'

export type Aviso = {
  id: number
  texto: string
  tipo: 'ok' | 'error'
}

const avisos = ref<Aviso[]>([])
let consecutivo = 0

export function useToast() {
  function mostrar(texto: string, tipo: Aviso['tipo']) {
    const id = ++consecutivo
    avisos.value = [...avisos.value, { id, texto, tipo }]
    window.setTimeout(() => {
      avisos.value = avisos.value.filter((aviso) => aviso.id !== id)
    }, 4200)
  }

  return {
    avisos,
    ok: (texto: string) => mostrar(texto, 'ok'),
    error: (texto: string) => mostrar(texto, 'error'),
  }
}
