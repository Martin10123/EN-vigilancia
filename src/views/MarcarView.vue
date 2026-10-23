<script setup lang="ts">
import { computed, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import CameraField from '@/components/CameraField.vue'
import PantallaCarga from '@/components/PantallaCarga.vue'
import LectorQr from '@/components/LectorQr.vue'
import { exigirCercania } from '@/lib/cerca'
import { enviarEvento } from '@/lib/cola'
import { mensajeError } from '@/lib/domain'
import { ubicacionActual } from '@/lib/geo'

const route = useRoute()
const router = useRouter()
const tipo = computed(() => (route.query.tipo === 'salida' ? 'salida' : 'entrada'))
const paso = ref<'inicio' | 'qr' | 'selfie' | 'enviando' | 'listo'>('inicio')
const token = ref('')
const error = ref('')
const encolado = ref(false)

async function leer(texto: string) {
  if (!texto.startsWith('caseta|')) {
    error.value = 'Ese QR no es el de la caseta.'
    paso.value = 'qr'
    return
  }
  token.value = texto
  error.value = ''
  paso.value = 'enviando'
  try {
    await exigirCercania()
    paso.value = 'selfie'
  } catch (causa) {
    error.value = mensajeError(causa)
    paso.value = 'qr'
  }
}

async function capturada(archivo: Blob) {
  paso.value = 'enviando'
  error.value = ''
  try {
    const punto = await ubicacionActual()
    const resultado = await enviarEvento({
      clase: 'marcacion',
      token: token.value,
      lat: punto.lat,
      lng: punto.lng,
      foto: archivo,
      tipo: tipo.value,
      descripcion: '',
    })
    encolado.value = resultado.encolado
    paso.value = 'listo'
  } catch (causa) {
    error.value = mensajeError(causa)
    paso.value = 'selfie'
  }
}
</script>

<template>
  <section class="max-w-xl">
    <h1 class="text-3xl font-semibold tracking-tight">Marcar {{ tipo }}</h1>
    <PantallaCarga v-if="paso === 'enviando'" fija />
    <p v-if="error" class="mt-4 rounded-xl bg-rose-50 px-3 py-2 text-sm text-rose-800" role="alert">{{ error }}</p>
    <button v-if="paso === 'inicio'" type="button" class="btn-shine mt-4 inline-flex min-h-12 items-center rounded-xl bg-marca px-4 text-sm font-semibold text-white" @click="paso = 'qr'">Escanear QR de la caseta</button>
    <LectorQr v-if="paso === 'qr'" @leido="leer" @cancelar="paso = 'inicio'" />
    <div v-else-if="paso === 'selfie'" class="mt-4">
      <p class="mb-3 text-sm text-slate-600">Selfie en vivo. La galería no sirve.</p>
      <CameraField cara="user" etiqueta="Tomar selfie" @capturada="capturada" />
    </div>
    <div v-else-if="paso === 'listo'" class="mt-4 rounded-3xl bg-white p-4">
      <p class="font-semibold">{{ encolado ? 'Quedó en este celular.' : 'Quedó registrada.' }}</p>
      <button type="button" class="mt-4 text-sm font-semibold text-marca" @click="router.push('/')">Volver</button>
    </div>
  </section>
</template>
