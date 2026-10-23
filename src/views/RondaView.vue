<script setup lang="ts">
import { useQuery, useQueryClient } from '@tanstack/vue-query'
import { computed, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import CameraField from '@/components/CameraField.vue'
import PantallaCarga from '@/components/PantallaCarga.vue'
import LectorQr from '@/components/LectorQr.vue'
import { rpc } from '@/lib/api'
import { enviarEvento } from '@/lib/cola'
import { mensajeError, referenciaQr } from '@/lib/domain'
import { ubicacionActual } from '@/lib/geo'

type Punto = { id: string; nombre: string; orden: number; exige_foto: boolean; escaneado: boolean }
type Estado = {
  fuera: boolean
  mensaje?: string
  ventana?: { id: string; nombre: string }
  puntos?: Punto[]
}

const route = useRoute()
const router = useRouter()
const queryClient = useQueryClient()
const turnoId = computed(() => String(route.params.turnoId))
const escaneando = ref(false)
const token = ref('')
const pideFoto = ref(false)
const enviando = ref(false)
const error = ref('')

const estado = useQuery({
  queryKey: computed(() => ['ronda', turnoId.value]),
  queryFn: () => rpc<Estado>('estado_ronda', { turno_id: turnoId.value }),
})

function empezar() {
  error.value = ''
  escaneando.value = true
}

function leer(texto: string) {
  escaneando.value = false
  const refQr = referenciaQr(texto)
  if (refQr?.tipo !== 'punto') {
    error.value = 'Ese QR no es de un punto de control.'
    return
  }
  token.value = texto
  const punto = (estado.data.value?.puntos ?? []).find((item) => item.id === refQr.ref)
  pideFoto.value = punto?.exige_foto ?? true
  if (!pideFoto.value) void enviar(null)
}

async function enviar(foto: Blob | null) {
  enviando.value = true
  error.value = ''
  try {
    const punto = await ubicacionActual()
    const resultado = await enviarEvento({
      clase: 'escaneo',
      token: token.value,
      lat: punto.lat,
      lng: punto.lng,
      foto,
      tipo: '',
      descripcion: '',
    })
    error.value = ''
    if (resultado.encolado) error.value = 'Quedó en este celular.'
    token.value = ''
    await queryClient.invalidateQueries({ queryKey: ['ronda', turnoId.value] })
  } catch (causa) {
    error.value = mensajeError(causa)
  } finally {
    enviando.value = false
  }
}
</script>

<template>
  <section class="max-w-xl">
    <button type="button" class="text-sm font-semibold text-marca" @click="router.push('/')">Volver</button>
    <h1 class="mt-2 text-3xl font-semibold tracking-tight">{{ estado.data.value?.ventana?.nombre ?? 'Ronda' }}</h1>
    <PantallaCarga v-if="estado.isLoading.value || enviando" :fija="enviando" />
    <p v-else-if="estado.data.value?.fuera" class="mt-4 rounded-2xl bg-white p-4 text-sm">{{ estado.data.value.mensaje }}</p>
    <template v-else>
      <ul class="mt-4 space-y-2">
        <li v-for="punto in estado.data.value?.puntos ?? []" :key="punto.id" class="flex items-center justify-between rounded-2xl bg-white px-4 py-3 text-sm">
          <span>{{ punto.nombre }}{{ punto.exige_foto ? ' · con foto' : '' }}</span>
          <span class="font-semibold" :class="punto.escaneado ? 'text-marca' : 'text-slate-400'">{{ punto.escaneado ? 'Listo' : 'Pendiente' }}</span>
        </li>
      </ul>
      <button type="button" class="btn-shine mt-4 inline-flex min-h-12 items-center rounded-xl bg-marca px-4 text-sm font-semibold text-white" :disabled="enviando" @click="empezar">
        Escanear punto
      </button>
      <div v-if="token && pideFoto" class="mt-4">
        <p class="mb-2 text-sm text-slate-600">Este punto pide foto de la cámara.</p>
        <CameraField @capturada="enviar" />
      </div>
    </template>
    <p v-if="error" class="mt-4 rounded-xl bg-amber-50 px-3 py-2 text-sm text-amber-950" role="status">{{ error }}</p>
    <LectorQr v-if="escaneando" @leido="leer" @cancelar="escaneando = false" />
  </section>
</template>
