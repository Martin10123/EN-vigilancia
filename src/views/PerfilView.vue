<script setup lang="ts">
import InputText from 'primevue/inputtext'
import { ref } from 'vue'
import Boton from '@/components/Boton.vue'
import Campo from '@/components/Campo.vue'
import { rpc } from '@/lib/api'
import { mensajeError, nombreEstado } from '@/lib/domain'
import { useSessionStore } from '@/stores/session'
import { useToast } from '@/stores/toast'

const session = useSessionStore()
const toast = useToast()
const nombre = ref(session.perfil?.nombre ?? '')
const telefono = ref(session.perfil?.telefono ?? '')
const guardando = ref(false)

async function guardar() {
  guardando.value = true
  try {
    await rpc('actualizar_mi_perfil', { nombre: nombre.value, telefono: telefono.value })
    await session.cargarPerfil()
    toast.ok('Perfil actualizado.')
  } catch (error) {
    toast.error(mensajeError(error))
  } finally {
    guardando.value = false
  }
}
</script>

<template>
  <section class="max-w-xl">
    <h1 class="text-3xl font-semibold tracking-tight">Mi perfil</h1>
    <p class="mt-2 text-sm text-slate-600">{{ session.roles.map(nombreEstado).join(', ') || 'Sin rol' }}</p>
    <form class="mt-5 space-y-3" @submit.prevent="guardar">
      <Campo etiqueta="Nombre"><InputText v-model="nombre" /></Campo>
      <Campo etiqueta="Teléfono" ayuda="El residente de turno lo usa para llamar o escribir."><InputText v-model="telefono" inputmode="tel" /></Campo>
      <Boton tipo="submit" :disabled="guardando">Guardar</Boton>
    </form>
  </section>
</template>
