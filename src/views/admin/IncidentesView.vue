<script setup lang="ts">
import { useQuery } from '@tanstack/vue-query'
import Select from 'primevue/select'
import { computed, ref } from 'vue'
import Boton from '@/components/Boton.vue'
import PantallaCarga from '@/components/PantallaCarga.vue'
import Campo from '@/components/Campo.vue'
import FechaCampo from '@/components/FechaCampo.vue'
import FotoPrivada from '@/components/FotoPrivada.vue'
import { TIPOS_INCIDENTE, descargarCsv, fechaHora, nombreEstado } from '@/lib/domain'
import { supabase } from '@/lib/supabase'

type Incidente = {
  id: string
  tipo: string
  descripcion: string
  capturado_en: string
  offline: boolean
  foto_path: string
  vigilante_id: string
  vigilante: { nombre: string } | null
}
type Persona = { id: string; nombre: string }

const tipo = ref('')
const vigilante = ref('')
const desde = ref('')
const hasta = ref('')

const personas = useQuery({
  queryKey: ['personas-filtro'],
  queryFn: async () => {
    const { data, error } = await supabase.from('perfiles').select('id, nombre').order('nombre')
    if (error) throw error
    return (data ?? []) as Persona[]
  },
})

const incidentes = useQuery({
  queryKey: computed(() => ['incidentes', tipo.value, vigilante.value, desde.value, hasta.value]),
  queryFn: async () => {
    let consulta = supabase
      .from('incidentes')
      .select('id, tipo, descripcion, capturado_en, offline, foto_path, vigilante_id, vigilante:perfiles!incidentes_vigilante_id_fkey(nombre)')
      .order('capturado_en', { ascending: false })
    if (tipo.value) consulta = consulta.eq('tipo', tipo.value)
    if (vigilante.value) consulta = consulta.eq('vigilante_id', vigilante.value)
    if (desde.value) consulta = consulta.gte('capturado_en', new Date(`${desde.value}T00:00:00`).toISOString())
    if (hasta.value) consulta = consulta.lte('capturado_en', new Date(`${hasta.value}T23:59:59`).toISOString())
    const { data, error } = await consulta
    if (error) throw error
    return (data ?? []) as unknown as Incidente[]
  },
})

function exportar() {
  descargarCsv(
    'incidentes.csv',
    (incidentes.data.value ?? []).map((fila) => ({
      fecha: fechaHora(fila.capturado_en),
      offline: fila.offline ? 'capturado sin conexión' : 'hora del servidor',
      vigilante: fila.vigilante?.nombre ?? '',
      tipo: nombreEstado(fila.tipo),
      descripcion: fila.descripcion,
    })),
  )
}
</script>

<template>
  <section>
    <div class="flex flex-wrap items-end justify-between gap-3">
      <div>
        <h1 class="text-3xl font-semibold tracking-tight">Incidentes</h1>
      </div>
      <Boton variante="secundario" :disabled="(incidentes.data.value ?? []).length === 0" @click="exportar">CSV</Boton>
    </div>
    <div class="mt-4 grid gap-3 sm:grid-cols-4">
      <Campo etiqueta="Desde"><FechaCampo v-model="desde" /></Campo>
      <Campo etiqueta="Hasta"><FechaCampo v-model="hasta" /></Campo>
      <Campo etiqueta="Tipo">
        <Select v-model="tipo" :options="[{ id: '', nombre: 'Todos' }, ...TIPOS_INCIDENTE]" option-label="nombre" option-value="id" />
      </Campo>
      <Campo etiqueta="Vigilante">
        <Select v-model="vigilante" :options="[{ id: '', nombre: 'Todos' }, ...(personas.data.value ?? [])]" option-label="nombre" option-value="id" />
      </Campo>
    </div>
    <PantallaCarga v-if="incidentes.isLoading.value" />
    <ul v-else class="mt-4 space-y-3">
      <li v-for="fila in incidentes.data.value ?? []" :key="fila.id" class="rounded-3xl bg-white p-4 text-sm">
        <p class="font-semibold">{{ nombreEstado(fila.tipo) }} · {{ fila.vigilante?.nombre }}</p>
        <p class="text-slate-500">
          {{ fechaHora(fila.capturado_en) }}
        </p>
        <p class="mt-2">{{ fila.descripcion }}</p>
        <FotoPrivada class="mt-3" :path="fila.foto_path" alt="Foto del incidente" />
      </li>
    </ul>
  </section>
</template>
