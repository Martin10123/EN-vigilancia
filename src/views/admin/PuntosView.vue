<script setup lang="ts">
import { useQuery, useQueryClient } from '@tanstack/vue-query'
import Checkbox from 'primevue/checkbox'
import InputText from 'primevue/inputtext'
import { ref } from 'vue'
import { RouterLink } from 'vue-router'
import Boton from '@/components/Boton.vue'
import PantallaCarga from '@/components/PantallaCarga.vue'
import Campo from '@/components/Campo.vue'
import NumeroCampo from '@/components/NumeroCampo.vue'
import { rpc } from '@/lib/api'
import { mensajeError } from '@/lib/domain'
import { supabase } from '@/lib/supabase'
import { useToast } from '@/stores/toast'

type Punto = { id: string; nombre: string; orden: number; exige_foto: boolean; activo: boolean }

const toast = useToast()
const queryClient = useQueryClient()
const nombre = ref('')
const orden = ref<number | null>(1)
const exigeFoto = ref(false)

const puntos = useQuery({
  queryKey: ['puntos'],
  queryFn: async () => {
    const { data, error } = await supabase.from('puntos_control').select('id, nombre, orden, exige_foto, activo').order('orden')
    if (error) throw error
    return (data ?? []) as Punto[]
  },
})

async function crear() {
  try {
    await rpc('guardar_punto', { punto_id: null, nombre: nombre.value, orden: orden.value ?? 1, exige_foto: exigeFoto.value })
    nombre.value = ''
    toast.ok('Punto creado.')
    await queryClient.invalidateQueries({ queryKey: ['puntos'] })
  } catch (error) {
    toast.error(mensajeError(error))
  }
}

async function rotar(id: string) {
  try {
    await rpc('rotar_punto', { punto_id: id })
    toast.ok('El QR anterior dejó de servir.')
    await queryClient.invalidateQueries({ queryKey: ['puntos'] })
  } catch (error) {
    toast.error(mensajeError(error))
  }
}

async function desactivar(id: string) {
  try {
    await rpc('desactivar_punto', { punto_id: id })
    await queryClient.invalidateQueries({ queryKey: ['puntos'] })
  } catch (error) {
    toast.error(mensajeError(error))
  }
}
</script>

<template>
  <section>
    <h1 class="text-3xl font-semibold tracking-tight">Puntos de control</h1>
    <form class="mt-4 grid gap-3 rounded-3xl bg-white p-4 sm:grid-cols-2" @submit.prevent="crear">
      <Campo etiqueta="Nombre"><InputText v-model="nombre" required /></Campo>
      <Campo etiqueta="Orden"><NumeroCampo v-model="orden" /></Campo>
      <label class="inline-flex min-h-11 items-center gap-2 text-sm sm:col-span-2">
        <Checkbox v-model="exigeFoto" binary /> Pedir foto al escanear
      </label>
      <Boton tipo="submit">Agregar punto</Boton>
    </form>
    <PantallaCarga v-if="puntos.isLoading.value" />
    <ul v-else class="mt-4 space-y-2">
      <li v-for="punto in puntos.data.value ?? []" :key="punto.id" class="rounded-2xl bg-white p-4 text-sm">
        <p class="font-semibold">{{ punto.orden }}. {{ punto.nombre }}</p>
        <p class="text-slate-500">{{ punto.exige_foto ? 'Con foto' : 'Sin foto' }} · {{ punto.activo ? 'Activo' : 'Inactivo' }}</p>
        <div v-if="punto.activo" class="mt-2 flex flex-wrap gap-3">
          <RouterLink :to="`/qr/punto/${punto.id}`" class="font-semibold text-marca">Imprimir QR</RouterLink>
          <button type="button" class="font-semibold" @click="rotar(punto.id)">Invalidar QR</button>
          <button type="button" class="font-semibold text-rose-700" @click="desactivar(punto.id)">Desactivar</button>
        </div>
      </li>
    </ul>
  </section>
</template>
