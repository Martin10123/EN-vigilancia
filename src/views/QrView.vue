<script setup lang="ts">
import QRCode from 'qrcode'
import { computed, ref, watch } from 'vue'
import { useRoute } from 'vue-router'
import Boton from '@/components/Boton.vue'
import PantallaCarga from '@/components/PantallaCarga.vue'
import { rpc } from '@/lib/api'
import { mensajeError } from '@/lib/domain'

const route = useRoute()
const canvas = ref<HTMLCanvasElement | null>(null)
const token = ref('')
const error = ref('')
const titulo = computed(() => (route.params.clase === 'punto' ? 'Punto de control' : 'Caseta'))

function imprimir() {
  window.print()
}

watch(
  () => [route.params.clase, route.params.id] as const,
  async ([clase, id]) => {
    error.value = ''
    token.value = ''
    try {
      token.value = clase === 'punto'
        ? await rpc<string>('token_punto', { punto_id: id })
        : await rpc<string>('token_caseta', { turno_id: id })
    } catch (causa) {
      error.value = mensajeError(causa)
    }
  },
  { immediate: true },
)

watch([token, canvas], async () => {
  if (!token.value || !canvas.value) return
  await QRCode.toCanvas(canvas.value, token.value, { width: 280, margin: 2 })
})
</script>

<template>
  <section class="mx-auto max-w-md text-center">
    <h1 class="text-3xl font-semibold tracking-tight">QR de {{ titulo }}</h1>
    <p v-if="error" class="mt-4 text-sm text-rose-700" role="alert">{{ error }}</p>
    <PantallaCarga v-if="!token && !error" />
    <canvas v-show="token" ref="canvas" class="mx-auto mt-6 rounded-2xl bg-white p-4" />
    <Boton class="no-print mt-4" @click="imprimir">Imprimir</Boton>
  </section>
</template>
