<script setup lang="ts">
import { useQuery, useQueryClient } from '@tanstack/vue-query'
import Select from 'primevue/select'
import { computed, ref, watch } from 'vue'
import Boton from '@/components/Boton.vue'
import PantallaCarga from '@/components/PantallaCarga.vue'
import Campo from '@/components/Campo.vue'
import FechaCampo from '@/components/FechaCampo.vue'
import FechaHoraCampo from '@/components/FechaHoraCampo.vue'
import { rpc } from '@/lib/api'
import { fechaHora, mensajeError, nombreEstado } from '@/lib/domain'
import { supabase } from '@/lib/supabase'
import { useToast } from '@/stores/toast'

type Vigilante = { id: string; nombre: string; perfil_roles: { rol_id: string }[] | null }
type Turno = { id: string; inicio: string; fin: string; estado: string; vigilante: { nombre: string } | null }

function iso(fecha: Date) {
  const mes = String(fecha.getMonth() + 1).padStart(2, '0')
  const dia = String(fecha.getDate()).padStart(2, '0')
  return `${fecha.getFullYear()}-${mes}-${dia}`
}

function leerFecha(valor: string) {
  const [anio, mes, dia] = valor.split('-').map(Number)
  return new Date(anio, mes - 1, dia)
}

function etiquetaCorta(fecha: Date) {
  return fecha.toLocaleDateString('es-CO', { day: '2-digit', month: 'short' })
}

function etiquetaLarga(fecha: Date) {
  return fecha.toLocaleDateString('es-CO', { day: '2-digit', month: 'short', year: 'numeric' })
}

const hoy = new Date()
const quince = new Date()
quince.setDate(hoy.getDate() + 13)

const toast = useToast()
const queryClient = useQueryClient()
const orden = ref<string[]>([])
const porAgregar = ref('')
const ancla = ref(iso(hoy))
const verDesde = ref(iso(hoy))
const verHasta = ref(iso(quince))
const inicio = ref<Date | null>(null)
const fin = ref<Date | null>(null)
const guardando = ref(false)
const creando = ref(false)

const vigilantes = useQuery({
  queryKey: ['vigilantes'],
  queryFn: async () => {
    const { data, error } = await supabase.from('perfiles').select('id, nombre, perfil_roles(rol_id)').eq('activo', true).order('nombre')
    if (error) throw error
    return ((data ?? []) as Vigilante[]).filter((fila) => (fila.perfil_roles ?? []).some((rol) => rol.rol_id === 'vigilante'))
  },
})

const turnos = useQuery({
  queryKey: computed(() => ['turnos-admin', verDesde.value, verHasta.value]),
  queryFn: async () => {
    let consulta = supabase
      .from('turnos')
      .select('id, inicio, fin, estado, vigilante:perfiles!turnos_vigilante_id_fkey(nombre)')
      .order('inicio', { ascending: true })
    if (verDesde.value) consulta = consulta.gte('inicio', leerFecha(verDesde.value).toISOString())
    if (verHasta.value) {
      const limite = leerFecha(verHasta.value)
      limite.setDate(limite.getDate() + 1)
      consulta = consulta.lt('inicio', limite.toISOString())
    }
    const { data, error } = await consulta
    if (error) throw error
    return (data ?? []) as unknown as Turno[]
  },
})

function nombreDe(id: string) {
  return vigilantes.data.value?.find((fila) => fila.id === id)?.nombre ?? '—'
}

function quienes(indice: number, ids: string[]) {
  const total = ids.length
  const bloque = Math.floor(indice / 2) % total
  return { manana: ids[(total - bloque) % total], noche: ids[(1 - bloque + total) % total] }
}

const disponibles = computed(() => (vigilantes.data.value ?? []).filter((fila) => !orden.value.includes(fila.id)))

const muestra = computed(() => {
  if (!/^\d{4}-\d{2}-\d{2}/.test(ancla.value) || orden.value.length < 3) return []
  const base = leerFecha(ancla.value)
  const dias = orden.value.length * 2
  return Array.from({ length: dias }, (_, indice) => {
    const fecha = new Date(base)
    fecha.setDate(base.getDate() + indice)
    const siguiente = new Date(fecha)
    siguiente.setDate(fecha.getDate() + 1)
    const turno = quienes(indice, orden.value)
    const descansan = orden.value.filter((id) => id !== turno.manana && id !== turno.noche).map(nombreDe)
    return {
      fecha: etiquetaCorta(fecha),
      manana: nombreDe(turno.manana),
      noche: nombreDe(turno.noche),
      sale: etiquetaCorta(siguiente),
      descansan: descansan.join(', '),
    }
  })
})

watch(vigilantes.data, (lista) => {
  if (!lista?.length || orden.value.length) return
  orden.value = lista.map((fila) => fila.id)
})

function agregar() {
  if (!porAgregar.value || orden.value.includes(porAgregar.value)) return
  orden.value = [...orden.value, porAgregar.value]
  porAgregar.value = ''
}

function quitar(id: string) {
  orden.value = orden.value.filter((fila) => fila !== id)
}

function mover(indice: number, delta: number) {
  const destino = indice + delta
  if (destino < 0 || destino >= orden.value.length) return
  const copia = [...orden.value]
  const [fila] = copia.splice(indice, 1)
  copia.splice(destino, 0, fila)
  orden.value = copia
}

watch(inicio, (valor) => {
  if (!valor || !fin.value || fin.value > valor) return
  fin.value = new Date(valor.getTime() + 12 * 60 * 60 * 1000)
})

function aplicar(hora: number) {
  const entrada = leerFecha(ancla.value || iso(hoy))
  entrada.setHours(hora, 0, 0, 0)
  inicio.value = entrada
  fin.value = new Date(entrada.getTime() + 12 * 60 * 60 * 1000)
}

async function generar() {
  if (orden.value.length < 3 || !ancla.value) {
    toast.error('Hacen falta al menos tres vigilantes para que el que sale a las 6:00 a. m. descanse.')
    return
  }
  guardando.value = true
  try {
    const total = await rpc<number>('generar_secuencia', {
      orden: orden.value,
      desde: ancla.value,
    })
    const inicioCiclo = leerFecha(ancla.value)
    const hasta = new Date(inicioCiclo)
    hasta.setDate(inicioCiclo.getDate() + 364)
    const visible = new Date(inicioCiclo)
    visible.setDate(inicioCiclo.getDate() + 13)
    verDesde.value = ancla.value
    verHasta.value = iso(visible)
    toast.ok(`Quedaron ${total} turnos, del ${etiquetaLarga(inicioCiclo)} al ${etiquetaLarga(hasta)}.`)
    await queryClient.invalidateQueries({ queryKey: ['turnos-admin'] })
  } catch (error) {
    toast.error(mensajeError(error))
  } finally {
    guardando.value = false
  }
}

async function crear() {
  if (!vigilanteSuelto.value || !inicio.value || !fin.value) {
    toast.error('Elige el vigilante, la entrada y la salida.')
    return
  }
  if (fin.value <= inicio.value) {
    toast.error('La noche termina al día siguiente, a las 6:00 a. m.')
    return
  }
  creando.value = true
  try {
    await rpc('crear_turno', {
      vigilante_id: vigilanteSuelto.value,
      inicio: inicio.value.toISOString(),
      fin: fin.value.toISOString(),
    })
    toast.ok('Turno creado.')
    await queryClient.invalidateQueries({ queryKey: ['turnos-admin'] })
  } catch (error) {
    toast.error(mensajeError(error))
  } finally {
    creando.value = false
  }
}

const vigilanteSuelto = ref('')

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
    <PantallaCarga v-if="guardando || creando" fija />
    <PantallaCarga v-if="vigilantes.isLoading.value" />
    <template v-else>
    <form class="mt-4 grid gap-3 rounded-3xl bg-white p-4" @submit.prevent="generar">
      <Campo etiqueta="Secuencia">
        <ol class="space-y-2">
          <li v-for="(id, indice) in orden" :key="id" class="flex flex-wrap items-center justify-between gap-2 rounded-2xl bg-slate-50 px-3 py-2 text-sm">
            <span class="font-semibold">{{ indice + 1 }}. {{ nombreDe(id) }}</span>
            <span class="flex gap-3">
              <button type="button" class="font-semibold text-marca" @click="mover(indice, -1)">Subir</button>
              <button type="button" class="font-semibold text-marca" @click="mover(indice, 1)">Bajar</button>
              <button type="button" class="font-semibold text-rose-700" @click="quitar(id)">Quitar</button>
            </span>
          </li>
        </ol>
      </Campo>
      <div v-if="disponibles.length" class="grid gap-3 sm:grid-cols-[1fr_auto] sm:items-end">
        <Campo etiqueta="Sumar a la secuencia">
          <Select v-model="porAgregar" :options="disponibles" option-label="nombre" option-value="id" placeholder="Elige" />
        </Campo>
        <Boton variante="secundario" @click="agregar">Sumar</Boton>
      </div>
      <Campo etiqueta="Desde">
        <FechaCampo v-model="ancla" />
      </Campo>
      <p v-if="orden.length < 3" class="text-sm text-rose-700">
        Con menos de tres, el que termina la noche a las 6:00 a. m. tendría que entrar de día ese mismo día. Suma al siguiente vigilante para que el que sale descanse.
      </p>
      <ul v-else class="space-y-2 text-sm text-slate-700">
        <li v-for="fila in muestra" :key="fila.fecha">
          {{ fila.fecha }} · {{ fila.manana }} de día · {{ fila.noche }} de noche, sale el {{ fila.sale }} a las 6:00 a. m. · Descansan: {{ fila.descansan }}
        </li>
      </ul>
      <div>
        <Boton tipo="submit" :disabled="guardando || orden.length < 3">Armar el año</Boton>
      </div>
    </form>

    <form class="mt-4 grid gap-3 rounded-3xl bg-white p-4 sm:grid-cols-2" @submit.prevent="crear">
      <h2 class="text-sm font-semibold text-slate-800 sm:col-span-2">Un turno suelto</h2>
      <Campo etiqueta="Vigilante" class="sm:col-span-2">
        <Select v-model="vigilanteSuelto" :options="vigilantes.data.value ?? []" option-label="nombre" option-value="id" placeholder="Elige" />
      </Campo>
      <Campo etiqueta="Empieza"><FechaHoraCampo v-model="inicio" /></Campo>
      <Campo etiqueta="Termina" ayuda="Si la salida queda antes de la entrada, se corre doce horas. La noche termina al día siguiente.">
        <FechaHoraCampo v-model="fin" />
      </Campo>
      <div class="flex flex-wrap gap-2 sm:col-span-2">
        <Boton variante="secundario" @click="aplicar(6)">Turno día 6 a 6</Boton>
        <Boton variante="secundario" @click="aplicar(18)">Turno noche 6 a 6</Boton>
        <Boton tipo="submit" :disabled="creando">Crear turno</Boton>
      </div>
    </form>
    </template>

    <div class="mt-6 grid gap-3 sm:grid-cols-2">
      <Campo etiqueta="Ver desde"><FechaCampo v-model="verDesde" /></Campo>
      <Campo etiqueta="Ver hasta"><FechaCampo v-model="verHasta" /></Campo>
    </div>
    <PantallaCarga v-if="turnos.isLoading.value" />
    <ul v-else class="mt-4 space-y-2">
      <li v-for="turno in turnos.data.value ?? []" :key="turno.id" class="rounded-2xl bg-white p-4 text-sm">
        <p class="font-semibold">{{ turno.vigilante?.nombre }} · {{ nombreEstado(turno.estado) }}</p>
        <p class="text-slate-600">{{ fechaHora(turno.inicio) }} – {{ fechaHora(turno.fin) }}</p>
        <div v-if="turno.estado === 'programado'" class="mt-2">
          <button type="button" class="font-semibold text-rose-700" @click="cancelar(turno.id)">Cancelar</button>
        </div>
      </li>
    </ul>
  </section>
</template>
