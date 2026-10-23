<script setup lang="ts">
import { useQuery, useQueryClient } from '@tanstack/vue-query'
import InputText from 'primevue/inputtext'
import { ref } from 'vue'
import Boton from '@/components/Boton.vue'
import PantallaCarga from '@/components/PantallaCarga.vue'
import Campo from '@/components/Campo.vue'
import HoraCampo from '@/components/HoraCampo.vue'
import NumeroCampo from '@/components/NumeroCampo.vue'
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
const orden = ref<number | null>(3)

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
  if (!horaInicio.value || !horaFin.value) {
    toast.error('Indica la hora de inicio y la de fin.')
    return
  }
  try {
    await rpc('guardar_ventana', {
      ventana_id: null,
      nombre: nombre.value,
      hora_inicio: horaInicio.value,
      hora_fin: horaFin.value,
      orden: orden.value ?? 1,
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
    <PantallaCarga v-if="ventanas.isLoading.value" />
    <ul v-else class="mt-4 space-y-2">
      <li v-for="ventana in ventanas.data.value ?? []" :key="ventana.id" class="flex items-center justify-between rounded-2xl bg-white px-4 py-3 text-sm">
        <span>{{ ventana.orden }}. {{ ventana.nombre }} · {{ horaCorta(ventana.hora_inicio) }}–{{ horaCorta(ventana.hora_fin) }}</span>
        <button type="button" class="font-semibold text-rose-700" @click="borrar(ventana.id)">Quitar</button>
      </li>
    </ul>
    <form class="mt-4 grid gap-3 rounded-3xl bg-white p-4 sm:grid-cols-2" @submit.prevent="crear">
      <Campo etiqueta="Nombre" class="sm:col-span-2"><InputText v-model="nombre" required /></Campo>
      <Campo etiqueta="Desde"><HoraCampo v-model="horaInicio" /></Campo>
      <Campo etiqueta="Hasta"><HoraCampo v-model="horaFin" /></Campo>
      <Campo etiqueta="Orden"><NumeroCampo v-model="orden" /></Campo>
      <Boton tipo="submit">Agregar ventana</Boton>
    </form>
  </section>
</template>
