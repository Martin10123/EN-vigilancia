<script setup lang="ts">
import { useQuery, useQueryClient } from '@tanstack/vue-query'
import Select from 'primevue/select'
import { ref } from 'vue'
import { RouterLink } from 'vue-router'
import Boton from '@/components/Boton.vue'
import Campo from '@/components/Campo.vue'
import { campoClase } from '@/prime'
import { rpc } from '@/lib/api'
import { fechaHora, mensajeError, nombreEstado, turnoRapido } from '@/lib/domain'
import { supabase } from '@/lib/supabase'
import { useToast } from '@/stores/toast'

type Vigilante = { id: string; nombre: string; perfil_roles: { rol_id: string }[] | null }
type Turno = { id: string; inicio: string; fin: string; estado: string; vigilante: { nombre: string } | null }

const toast = useToast()
const queryClient = useQueryClient()
const vigilanteId = ref('')
const rapido = turnoRapido(18)
const inicio = ref(rapido.inicio)
const fin = ref(rapido.fin)
const guardando = ref(false)

const vigilantes = useQuery({
  queryKey: ['vigilantes'],
  queryFn: async () => {
    const { data, error } = await supabase.from('perfiles').select('id, nombre, perfil_roles(rol_id)').eq('activo', true).order('nombre')
    if (error) throw error
    return ((data ?? []) as Vigilante[]).filter((fila) => (fila.perfil_roles ?? []).some((rol) => rol.rol_id === 'vigilante'))
  },
})

const turnos = useQuery({
  queryKey: ['turnos-admin'],
  queryFn: async () => {
    const { data, error } = await supabase
      .from('turnos')
      .select('id, inicio, fin, estado, vigilante:perfiles!turnos_vigilante_id_fkey(nombre)')
      .order('inicio', { ascending: false })
      .limit(40)
    if (error) throw error
    return (data ?? []) as unknown as Turno[]
  },
})

function aplicar(hora: number) {
  const turno = turnoRapido(hora)
  inicio.value = turno.inicio
  fin.value = turno.fin
}

async function crear() {
  guardando.value = true
  try {
    await rpc('crear_turno', {
      vigilante_id: vigilanteId.value,
      inicio: new Date(inicio.value).toISOString(),
      fin: new Date(fin.value).toISOString(),
    })
    toast.ok('Turno creado.')
    await queryClient.invalidateQueries({ queryKey: ['turnos-admin'] })
  } catch (error) {
    toast.error(mensajeError(error))
  } finally {
    guardando.value = false
  }
}

async function cancelar(id: string) {
  try {
    await rpc('cancelar_turno', { turno_id: id })
    toast.ok('Turno cancelado.')
    await queryClient.invalidateQueries({ queryKey: ['turnos-admin'] })
  } catch (error) {
    toast.error(mensajeError(error))
  }
}
</script>

<template>
  <section>
    <h1 class="text-3xl font-semibold tracking-tight">Turnos</h1>
    <p class="mt-2 text-sm text-slate-600">Doce horas, de 6 a 6. El QR de la caseta cambia con cada turno.</p>
    <form class="mt-4 grid gap-3 rounded-3xl bg-white p-4 sm:grid-cols-2" @submit.prevent="crear">
      <Campo etiqueta="Vigilante" class="sm:col-span-2">
        <Select v-model="vigilanteId" :options="vigilantes.data.value ?? []" option-label="nombre" option-value="id" placeholder="Elige" />
      </Campo>
      <Campo etiqueta="Empieza"><input v-model="inicio" type="datetime-local" required :class="campoClase" /></Campo>
      <Campo etiqueta="Termina"><input v-model="fin" type="datetime-local" required :class="campoClase" /></Campo>
      <div class="flex flex-wrap gap-2 sm:col-span-2">
        <Boton variante="secundario" @click="aplicar(6)">Turno día 6 a 6</Boton>
        <Boton variante="secundario" @click="aplicar(18)">Turno noche 6 a 6</Boton>
        <Boton tipo="submit" :disabled="guardando">Crear turno</Boton>
      </div>
    </form>
    <ul class="mt-4 space-y-2">
      <li v-for="turno in turnos.data.value ?? []" :key="turno.id" class="rounded-2xl bg-white p-4 text-sm">
        <p class="font-semibold">{{ turno.vigilante?.nombre }} · {{ nombreEstado(turno.estado) }}</p>
        <p class="text-slate-600">{{ fechaHora(turno.inicio) }} – {{ fechaHora(turno.fin) }}</p>
        <div class="mt-2 flex flex-wrap gap-3">
          <RouterLink v-if="turno.estado !== 'cancelado'" :to="`/qr/caseta/${turno.id}`" class="font-semibold text-marca">QR de caseta</RouterLink>
          <button v-if="turno.estado === 'programado'" type="button" class="font-semibold text-rose-700" @click="cancelar(turno.id)">Cancelar</button>
        </div>
      </li>
    </ul>
  </section>
</template>
