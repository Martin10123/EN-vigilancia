<script setup lang="ts">
import { useQuery, useQueryClient } from '@tanstack/vue-query'
import InputText from 'primevue/inputtext'
import { ref } from 'vue'
import Boton from '@/components/Boton.vue'
import Campo from '@/components/Campo.vue'
import { campoClase } from '@/prime'
import { rpc } from '@/lib/api'
import { mensajeError } from '@/lib/domain'
import { supabase } from '@/lib/supabase'
import { useToast } from '@/stores/toast'

type Ventana = { id: string; nombre: string; hora_inicio: string; hora_fin: string; orden: number }

const toast = useToast()
const queryClient = useQueryClient()
const nombre = ref('')
const horaInicio = ref('20:00')
const horaFin = ref('22:00')
const orden = ref(3)

const ventanas = useQuery({
  queryKey: ['ventanas'],
  queryFn: async () => {
    const { data, error } = await supabase.from('ventanas_ronda').select('id, nombre, hora_inicio, hora_fin, orden').order('orden')
    if (error) throw error
    return (data ?? []) as Ventana[]
  },
})

function horaCorta(valor: string) {
  return valor.slice(0, 5)
}

async function crear() {
  try {
    await rpc('guardar_ventana', {
      ventana_id: null,
      nombre: nombre.value,
      hora_inicio: horaInicio.value,
      hora_fin: horaFin.value,
      orden: orden.value,
    })
    nombre.value = ''
    toast.ok('Ventana guardada.')
    await queryClient.invalidateQueries({ queryKey: ['ventanas'] })
  } catch (error) {
    toast.error(mensajeError(error))
  }
}

async function borrar(id: string) {
  try {
    await rpc('borrar_ventana', { ventana_id: id })
    await queryClient.invalidateQueries({ queryKey: ['ventanas'] })
  } catch (error) {
    toast.error(mensajeError(error))
  }
}
</script>

<template>
  <section>
    <h1 class="text-3xl font-semibold tracking-tight">Ventanas de ronda</h1>
    <p class="mt-2 text-sm text-slate-600">Por defecto, 8 a 10 pm y 2 a 4 am. El vigilante solo puede escanear dentro de la ventana.</p>
    <ul class="mt-4 space-y-2">
      <li v-for="ventana in ventanas.data.value ?? []" :key="ventana.id" class="flex items-center justify-between rounded-2xl bg-white px-4 py-3 text-sm">
        <span>{{ ventana.orden }}. {{ ventana.nombre }} · {{ horaCorta(ventana.hora_inicio) }}–{{ horaCorta(ventana.hora_fin) }}</span>
        <button type="button" class="font-semibold text-rose-700" @click="borrar(ventana.id)">Quitar</button>
      </li>
    </ul>
    <form class="mt-4 grid gap-3 rounded-3xl bg-white p-4 sm:grid-cols-2" @submit.prevent="crear">
      <Campo etiqueta="Nombre" class="sm:col-span-2"><InputText v-model="nombre" required /></Campo>
      <Campo etiqueta="Desde"><input v-model="horaInicio" type="time" required :class="campoClase" /></Campo>
      <Campo etiqueta="Hasta"><input v-model="horaFin" type="time" required :class="campoClase" /></Campo>
      <Campo etiqueta="Orden"><input v-model.number="orden" type="number" :class="campoClase" /></Campo>
      <Boton tipo="submit">Agregar ventana</Boton>
    </form>
  </section>
</template>
