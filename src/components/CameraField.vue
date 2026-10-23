<script setup lang="ts">
import { Camera } from 'lucide-vue-next'
import { onUnmounted, ref } from 'vue'
import { comprimirImagen } from '@/lib/media'

const props = withDefaults(
  defineProps<{
    cara?: 'user' | 'environment'
    etiqueta?: string
  }>(),
  { cara: 'environment', etiqueta: 'Tomar foto' },
)

const emit = defineEmits<{ capturada: [archivo: Blob] }>()
const video = ref<HTMLVideoElement | null>(null)
const abierta = ref(false)
const error = ref('')
let stream: MediaStream | null = null

async function abrir() {
  error.value = ''
  try {
    stream = await navigator.mediaDevices.getUserMedia({
      video: { facingMode: props.cara },
      audio: false,
    })
    abierta.value = true
    await new Promise((resolve) => requestAnimationFrame(resolve))
    if (video.value) {
      video.value.srcObject = stream
      await video.value.play()
    }
  } catch {
    error.value = 'No se pudo abrir la cámara. Revisa el permiso del navegador.'
  }
}

async function capturar() {
  const elemento = video.value
  if (!elemento) return
  const lienzo = document.createElement('canvas')
  lienzo.width = elemento.videoWidth
  lienzo.height = elemento.videoHeight
  const contexto = lienzo.getContext('2d')
  if (!contexto || lienzo.width === 0) return
  contexto.drawImage(elemento, 0, 0)
  const blob = await new Promise<Blob | null>((resolve) => lienzo.toBlob(resolve, 'image/jpeg', 0.9))
  if (!blob) return
  emit('capturada', await comprimirImagen(blob))
  cerrar()
}

function cerrar() {
  stream?.getTracks().forEach((pista) => pista.stop())
  stream = null
  abierta.value = false
}

onUnmounted(cerrar)
</script>

<template>
  <div>
    <button type="button" class="inline-flex min-h-12 items-center gap-2 rounded-xl bg-slate-900 px-4 text-sm font-semibold text-white" @click="abrir">
      <Camera class="size-4" aria-hidden="true" />
      {{ etiqueta }}
    </button>
    <p v-if="error" class="mt-2 text-sm text-rose-700" role="alert">{{ error }}</p>
    <div v-if="abierta" class="fixed inset-0 z-[70] flex flex-col bg-ink/95 p-4">
      <video ref="video" autoplay playsinline muted class="min-h-0 flex-1 rounded-2xl object-contain" />
      <div class="mt-4 flex gap-3">
        <button type="button" class="min-h-12 flex-1 rounded-xl bg-white font-semibold" @click="capturar">Usar esta foto</button>
        <button type="button" class="min-h-12 rounded-xl px-4 font-semibold text-white" @click="cerrar">Cancelar</button>
      </div>
    </div>
  </div>
</template>
