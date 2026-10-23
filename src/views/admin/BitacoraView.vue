<script setup lang="ts">
import { useQuery } from '@tanstack/vue-query'
import PantallaCarga from '@/components/PantallaCarga.vue'
import { fechaHora } from '@/lib/domain'
import { supabase } from '@/lib/supabase'

type Fila = {
  id: string
  creado_en: string
  nivel: string
  origen: string
  mensaje: string
  ruta: string | null
  detalle: string | null
  perfil: { nombre: string } | null
}

const filas = useQuery({
  queryKey: ['bitacora'],
  queryFn: async () => {
    const { data, error } = await supabase
      .from('bitacora')
      .select('id, creado_en, nivel, origen, mensaje, ruta, detalle, perfil:perfiles(nombre)')
      .order('creado_en', { ascending: false })
      .limit(80)
    if (error) throw error
    return (data ?? []) as unknown as Fila[]
  },
})
</script>

<template>
  <section>
    <h1 class="text-3xl font-semibold tracking-tight">Bitácora</h1>
    <PantallaCarga v-if="filas.isLoading.value" />
    <p v-else-if="(filas.data.value ?? []).length === 0" class="mt-4 text-sm text-slate-500">Todavía no hay errores registrados.</p>
    <ul v-else class="mt-4 space-y-2">
      <li v-for="fila in filas.data.value" :key="fila.id" class="rounded-2xl bg-white p-4 text-sm">
        <p class="font-semibold">{{ fila.mensaje }}</p>
        <p class="mt-1 text-slate-500">{{ fechaHora(fila.creado_en) }} · {{ fila.origen }} · {{ fila.perfil?.nombre || 'Sin perfil' }}</p>
        <p v-if="fila.ruta" class="text-slate-500">{{ fila.ruta }}</p>
        <p v-if="fila.detalle" class="mt-2 break-words text-slate-600">{{ fila.detalle }}</p>
      </li>
    </ul>
  </section>
</template>
