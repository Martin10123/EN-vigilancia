<script setup lang="ts">
import Select from 'primevue/select'
import Textarea from 'primevue/textarea'
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import AvisoLimite from '@/components/AvisoLimite.vue'
import Boton from '@/components/Boton.vue'
import CameraField from '@/components/CameraField.vue'
import Campo from '@/components/Campo.vue'
import { enviarEvento } from '@/lib/cola'
import { TIPOS_INCIDENTE, mensajeError } from '@/lib/domain'
import { ubicacionActual } from '@/lib/geo'

const router = useRouter()
const tipo = ref('novedad')
const descripcion = ref('')
const foto = ref<Blob | null>(null)
const enviando = ref(false)
const error = ref('')
const listo = ref('')

async function enviar() {
  error.value = ''
  if (!foto.value || descripcion.value.trim().length < 3) {
    error.value = 'Toma la foto y describe lo que pasó.'
    return
  }
  enviando.value = true
  try {
    const punto = await ubicacionActual()
    const resultado = await enviarEvento({
      clase: 'incidente',
      token: '',
      lat: punto.lat,
      lng: punto.lng,
      foto: foto.value,
      tipo: tipo.value,
      descripcion: descripcion.value.trim(),
    })
    listo.value = resultado.encolado
      ? 'Quedó en este celular. No se podrá editar cuando sincronice, y la hora oficial será la de la sincronización.'
      : 'Quedó enviado. No se puede editar.'
  } catch (causa) {
    error.value = mensajeError(causa)
  } finally {
    enviando.value = false
  }
}
</script>

<template>
  <section class="max-w-xl">
    <h1 class="text-3xl font-semibold tracking-tight">Incidente</h1>
    <p class="mt-2 text-sm text-slate-600">Foto en vivo, hora del servidor y descripción. Después de enviado no se cambia.</p>
    <AvisoLimite clave="hash" class="mt-4" />
    <form v-if="!listo" class="mt-4 space-y-3" @submit.prevent="enviar">
      <Campo etiqueta="Tipo">
        <Select v-model="tipo" :options="[...TIPOS_INCIDENTE]" option-label="nombre" option-value="id" />
      </Campo>
      <Campo etiqueta="Qué pasó">
        <Textarea v-model="descripcion" rows="4" />
      </Campo>
      <CameraField @capturada="foto = $event" />
      <p v-if="foto" class="text-sm text-slate-600">Foto lista.</p>
      <p v-if="error" class="rounded-xl bg-rose-50 px-3 py-2 text-sm text-rose-800" role="alert">{{ error }}</p>
      <Boton tipo="submit" :disabled="enviando">{{ enviando ? 'Enviando…' : 'Enviar incidente' }}</Boton>
    </form>
    <div v-else class="mt-4 rounded-3xl bg-white p-4">
      <p>{{ listo }}</p>
      <button type="button" class="mt-4 text-sm font-semibold text-marca" @click="router.push('/')">Volver</button>
    </div>
  </section>
</template>
