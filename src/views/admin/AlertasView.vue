<script setup lang="ts">
import { useQuery, useQueryClient } from '@tanstack/vue-query'
import Boton from '@/components/Boton.vue'
import { rpc } from '@/lib/api'
import { descargarCsv, fechaHora, mensajeError, nombreEstado } from '@/lib/domain'
import { supabase } from '@/lib/supabase'
import { useToast } from '@/stores/toast'

type Alerta = { id: string; tipo: string; detalle: string; leida: boolean; creada_en: string }

const toast = useToast()
const queryClient = useQueryClient()

const alertas = useQuery({
  queryKey: ['alertas'],
  queryFn: async () => {
    await rpc('revisar_alertas')
    const { data, error } = await supabase.from('alertas').select('id, tipo, detalle, leida, creada_en').order('creada_en', { ascending: false })
    if (error) throw error
    return (data ?? []) as Alerta[]
  },
})

async function leer(id: string) {
  try {
    await rpc('marcar_alerta_leida', { alerta_id: id })
    await queryClient.invalidateQueries({ queryKey: ['alertas'] })
  } catch (error) {
    toast.error(mensajeError(error))
  }
}

function exportar() {
  descargarCsv(
    'alertas.csv',
    (alertas.data.value ?? []).map((fila) => ({
      fecha: fechaHora(fila.creada_en),
      tipo: nombreEstado(fila.tipo),
      detalle: fila.detalle,
      leida: fila.leida ? 'sí' : 'no',
    })),
  )
}
</script>

<template>
  <section>
    <div class="flex items-end justify-between gap-3">
      <div>
        <h1 class="text-3xl font-semibold tracking-tight">Alertas</h1>
        <p class="mt-2 text-sm text-slate-600">Entrada tarde, ronda incompleta o intento fuera del radio. Se calculan al abrir esta pantalla.</p>
      </div>
      <Boton variante="secundario" :disabled="(alertas.data.value ?? []).length === 0" @click="exportar">CSV</Boton>
    </div>
    <ul class="mt-4 space-y-2">
      <li v-for="alerta in alertas.data.value ?? []" :key="alerta.id" class="rounded-2xl bg-white p-4 text-sm">
        <p class="font-semibold">{{ nombreEstado(alerta.tipo) }}</p>
        <p class="text-slate-600">{{ alerta.detalle }}</p>
        <p class="mt-1 text-slate-500">{{ fechaHora(alerta.creada_en) }}</p>
        <button v-if="!alerta.leida" type="button" class="mt-2 font-semibold text-marca" @click="leer(alerta.id)">Marcar leída</button>
      </li>
    </ul>
  </section>
</template>
