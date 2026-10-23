<script setup lang="ts">
import { useQuery } from '@tanstack/vue-query'
import { ChevronLeft, ChevronRight } from 'lucide-vue-next'
import { computed, ref } from 'vue'
import PantallaCarga from '@/components/PantallaCarga.vue'
import { nombreEstado } from '@/lib/domain'
import { supabase } from '@/lib/supabase'

type Turno = { id: string; inicio: string; fin: string; estado: string }

const zona = 'America/Bogota'
const semana = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom']

function hoyBogota() {
  const texto = new Intl.DateTimeFormat('en-CA', { timeZone: zona, year: 'numeric', month: '2-digit', day: '2-digit' }).format(new Date())
  const [anio, mes, dia] = texto.split('-').map(Number)
  return { anio, mes, dia }
}

function clave(anio: number, mes: number, dia: number) {
  return `${anio}-${String(mes).padStart(2, '0')}-${String(dia).padStart(2, '0')}`
}

function partes(iso: string) {
  const mapa = Object.fromEntries(
    new Intl.DateTimeFormat('en-US', {
      timeZone: zona,
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
      hour: '2-digit',
      minute: '2-digit',
      hourCycle: 'h23',
    })
      .formatToParts(new Date(iso))
      .map((parte) => [parte.type, parte.value]),
  )
  return {
    fecha: `${mapa.year}-${mapa.month}-${mapa.day}`,
    hora: Number(mapa.hour),
  }
}

function hora(iso: string) {
  return new Intl.DateTimeFormat('es-CO', { timeZone: zona, hour: 'numeric', minute: '2-digit' }).format(new Date(iso))
}

function frase(texto: string) {
  return texto.charAt(0).toLocaleUpperCase('es-CO') + texto.slice(1)
}

function diaTexto(fecha: string) {
  const [anio, mes, dia] = fecha.split('-').map(Number)
  return frase(
    new Date(Date.UTC(anio, mes - 1, dia)).toLocaleDateString('es-CO', {
      weekday: 'long',
      day: 'numeric',
      month: 'long',
      timeZone: 'UTC',
    }),
  )
}

const hoy = hoyBogota()
const cursor = ref({ anio: hoy.anio, mes: hoy.mes })
const elegido = ref(clave(hoy.anio, hoy.mes, hoy.dia))

const titulo = computed(() =>
  frase(
    new Date(Date.UTC(cursor.value.anio, cursor.value.mes - 1, 1)).toLocaleDateString('es-CO', {
      month: 'long',
      year: 'numeric',
      timeZone: 'UTC',
    }),
  ),
)

const celdas = computed(() => {
  const { anio, mes } = cursor.value
  const primero = new Date(Date.UTC(anio, mes - 1, 1))
  const huecos = (primero.getUTCDay() + 6) % 7
  const cantidad = new Date(Date.UTC(anio, mes, 0)).getUTCDate()
  const dias: Array<number | null> = [...Array(huecos).fill(null), ...Array.from({ length: cantidad }, (_, indice) => indice + 1)]
  while (dias.length % 7) dias.push(null)
  return dias
})

const turnos = useQuery({
  queryKey: computed(() => ['calendario-vigilante', cursor.value.anio, cursor.value.mes]),
  queryFn: async () => {
    const { anio, mes } = cursor.value
    const desde = new Date(Date.UTC(anio, mes - 1, 1, 5, 0, 0)).toISOString()
    const hasta = new Date(Date.UTC(anio, mes, 1, 5, 0, 0)).toISOString()
    const { data, error } = await supabase
      .from('turnos')
      .select('id, inicio, fin, estado')
      .neq('estado', 'cancelado')
      .gt('fin', desde)
      .lt('inicio', hasta)
      .order('inicio')
    if (error) throw error
    return (data ?? []) as Turno[]
  },
})

type Marca = { id: string; tono: string; titulo: string; detalle: string; estado: string }

function sumarDias(fecha: string, delta: number) {
  const [anio, mes, dia] = fecha.split('-').map(Number)
  const siguiente = new Date(Date.UTC(anio, mes - 1, dia + delta))
  return clave(siguiente.getUTCFullYear(), siguiente.getUTCMonth() + 1, siguiente.getUTCDate())
}

const marcasPorFecha = computed(() => {
  const mapa = new Map<string, Marca[]>()
  const agregar = (fecha: string, marca: Marca) => {
    const lista = mapa.get(fecha) ?? []
    lista.push(marca)
    mapa.set(fecha, lista)
  }
  let desde = ''
  let hasta = ''
  for (const turno of turnos.data.value ?? []) {
    const entra = partes(turno.inicio)
    const sale = partes(turno.fin)
    const noche = entra.hora >= 12
    const cruza = sale.fecha !== entra.fecha
    const detalle = cruza ? `${hora(turno.inicio)} – ${hora(turno.fin)} del día siguiente` : `${hora(turno.inicio)} – ${hora(turno.fin)}`
    agregar(entra.fecha, { id: turno.id, tono: noche ? 'noche' : 'dia', titulo: noche ? 'Noche' : 'Día', detalle, estado: turno.estado })
    if (cruza) agregar(sale.fecha, { id: `${turno.id}-sale`, tono: 'sale', titulo: 'Sales', detalle: hora(turno.fin), estado: turno.estado })
    const finRango = cruza ? sale.fecha : entra.fecha
    if (!desde || entra.fecha < desde) desde = entra.fecha
    if (!hasta || finRango > hasta) hasta = finRango
  }
  const trabaja = (fecha: string) => (mapa.get(fecha) ?? []).some((marca) => marca.tono === 'dia' || marca.tono === 'noche')
  if (desde && hasta) {
    for (let fecha = desde; fecha <= hasta; fecha = sumarDias(fecha, 1)) {
      if (trabaja(fecha)) continue
      const sale = (mapa.get(fecha) ?? []).find((marca) => marca.tono === 'sale')
      agregar(fecha, {
        id: `descanso-${fecha}`,
        tono: 'descanso',
        titulo: 'Descanso',
        detalle: sale ? `sales a las ${sale.detalle}` : 'día completo',
        estado: '',
      })
      if (sale) mapa.set(fecha, (mapa.get(fecha) ?? []).filter((marca) => marca.tono !== 'sale'))
    }
  }
  return mapa
})

function marcas(fecha: string) {
  return marcasPorFecha.value.get(fecha) ?? []
}

const delDia = computed(() => marcas(elegido.value))

function mover(delta: number) {
  const fecha = new Date(Date.UTC(cursor.value.anio, cursor.value.mes - 1 + delta, 1))
  cursor.value = { anio: fecha.getUTCFullYear(), mes: fecha.getUTCMonth() + 1 }
  elegido.value = clave(cursor.value.anio, cursor.value.mes, 1)
}

function elegir(dia: number) {
  elegido.value = clave(cursor.value.anio, cursor.value.mes, dia)
}
</script>

<template>
  <section>
    <h1 class="text-3xl font-semibold tracking-tight">Mi calendario</h1>
    <PantallaCarga v-if="turnos.isLoading.value" />
    <template v-else>

    <div class="mt-4 rounded-3xl bg-white p-3 sm:p-4">
      <div class="flex items-center justify-between gap-2">
        <button type="button" class="grid size-11 place-items-center rounded-xl text-slate-700 hover:bg-slate-100" aria-label="Mes anterior" @click="mover(-1)">
          <ChevronLeft class="size-5" aria-hidden="true" />
        </button>
        <h2 class="text-base font-semibold">{{ titulo }}</h2>
        <button type="button" class="grid size-11 place-items-center rounded-xl text-slate-700 hover:bg-slate-100" aria-label="Mes siguiente" @click="mover(1)">
          <ChevronRight class="size-5" aria-hidden="true" />
        </button>
      </div>

      <div class="mt-3 grid grid-cols-7 gap-1 text-center text-[11px] font-semibold tracking-wide text-slate-400 uppercase">
        <span v-for="nombre in semana" :key="nombre">{{ nombre }}</span>
      </div>
      <div class="mt-1 grid grid-cols-7 gap-1">
        <div v-for="(dia, indice) in celdas" :key="indice">
          <button
            v-if="dia"
            type="button"
            class="flex min-h-16 w-full flex-col items-center rounded-xl px-0.5 py-1 text-xs"
            :class="elegido === clave(cursor.anio, cursor.mes, dia) ? 'bg-marca text-white' : 'hover:bg-slate-50'"
            @click="elegir(dia)"
          >
            <span class="font-semibold" :class="clave(cursor.anio, cursor.mes, dia) === clave(hoy.anio, hoy.mes, hoy.dia) && elegido !== clave(cursor.anio, cursor.mes, dia) ? 'text-marca' : ''">{{ dia }}</span>
            <span v-for="marca in marcas(clave(cursor.anio, cursor.mes, dia))" :key="marca.id" class="mt-0.5 max-w-full truncate rounded px-1 text-[10px] font-semibold" :class="elegido === clave(cursor.anio, cursor.mes, dia) ? 'bg-white/20' : marca.tono === 'noche' ? 'bg-slate-900 text-white' : marca.tono === 'descanso' ? 'bg-emerald-100 text-emerald-900' : marca.tono === 'sale' ? 'bg-slate-100 text-slate-600' : 'bg-amber-100 text-amber-900'">
              {{ marca.titulo }}
            </span>
          </button>
        </div>
      </div>
    </div>

    <div class="mt-4 rounded-3xl bg-white p-4">
      <h2 class="text-lg font-semibold">{{ diaTexto(elegido) }}</h2>
      <p v-if="turnos.isError.value" class="mt-2 text-sm text-red-700">No pude cargar los turnos.</p>
      <p v-else-if="delDia.length === 0" class="mt-2 text-sm text-slate-500">Sin turno.</p>
      <ul v-else class="mt-3 space-y-2">
        <li v-for="marca in delDia" :key="marca.id" class="rounded-2xl bg-slate-50 px-3 py-3 text-sm">
          <p class="font-semibold">{{ marca.titulo }} · {{ marca.detalle }}</p>
          <p v-if="marca.estado" class="text-slate-600">{{ nombreEstado(marca.estado) }}</p>
        </li>
      </ul>
    </div>
    </template>
  </section>
</template>
