<script setup lang="ts">
import { onMounted, ref } from 'vue'
import AvisoLimite from '@/components/AvisoLimite.vue'
import Boton from '@/components/Boton.vue'
import { listarCola, sincronizar, type EventoLocal } from '@/lib/cola'
import { fechaHora, nombreEstado } from '@/lib/domain'

const filas = ref<EventoLocal[]>([])
const trabajando = ref(false)

async function cargar() {
  filas.value = await listarCola()
}

async function sincronizarAhora() {
  trabajando.value = true
  await sincronizar()
  await cargar()
  trabajando.value = false
}

onMounted(cargar)
</script>

<template>
  <section class="max-w-xl">
    <h1 class="text-3xl font-semibold tracking-tight">Pendientes de sincronizar</h1>
    <AvisoLimite clave="offline" class="mt-4" />
    <Boton class="mt-4" :disabled="trabajando || filas.length === 0" @click="sincronizarAhora">Sincronizar</Boton>
    <p v-if="filas.length === 0" class="mt-4 text-sm text-slate-500">No hay registros esperando red.</p>
    <ul v-else class="mt-4 space-y-2">
      <li v-for="fila in filas" :key="fila.id" class="rounded-2xl bg-white p-4 text-sm">
        <p class="font-semibold">{{ nombreEstado(fila.clase) }} {{ fila.tipo }}</p>
        <p class="text-slate-600">Hora de este celular, sin verificar: {{ fechaHora(fila.guardadoEn) }}</p>
        <p v-if="fila.error" class="mt-1 text-rose-700">{{ fila.error }}</p>
      </li>
    </ul>
  </section>
</template>
