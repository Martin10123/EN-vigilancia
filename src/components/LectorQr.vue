<script setup lang="ts">
import { BrowserQRCodeReader } from '@zxing/browser'
import { onMounted, onUnmounted, ref } from 'vue'

const emit = defineEmits<{ leido: [texto: string]; cancelar: [] }>()
const video = ref<HTMLVideoElement | null>(null)
const error = ref('')
let controles: { stop: () => void } | null = null
let cerrado = false

onMounted(async () => {
  const lector = new BrowserQRCodeReader()
  try {
    controles = await lector.decodeFromConstraints(
      { video: { facingMode: { ideal: 'environment' } } },
      video.value!,
      (resultado) => {
        if (!resultado || cerrado) return
        cerrado = true
        controles?.stop()
        emit('leido', resultado.getText())
      },
    )
  } catch {
    error.value = 'No se pudo abrir la cámara para leer el QR.'
  }
})

onUnmounted(() => {
  cerrado = true
  controles?.stop()
})
</script>

<template>
  <div class="fixed inset-0 z-[70] flex flex-col bg-ink/95 p-4">
    <p class="mb-3 text-sm font-medium text-white">Apunta al QR. No se aceptan fotos de la galería.</p>
    <video ref="video" autoplay playsinline muted class="min-h-0 flex-1 rounded-2xl object-cover" />
    <p v-if="error" class="mt-3 text-sm text-rose-200" role="alert">{{ error }}</p>
    <button type="button" class="mt-4 min-h-12 rounded-xl bg-white font-semibold" @click="emit('cancelar')">Cancelar</button>
  </div>
</template>
