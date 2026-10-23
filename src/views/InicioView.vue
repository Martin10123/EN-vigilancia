<script setup lang="ts">
import { useQuery, useQueryClient } from '@tanstack/vue-query'
import { computed } from 'vue'
import { RouterLink } from 'vue-router'
import Boton from '@/components/Boton.vue'
import PantallaCarga from '@/components/PantallaCarga.vue'
import FotoPrivada from '@/components/FotoPrivada.vue'
import { rpc } from '@/lib/api'
import { fechaHora, mensajeError, nombreEstado, telefonoWhatsapp } from '@/lib/domain'
import { supabase } from '@/lib/supabase'
import { useSessionStore } from '@/stores/session'
import { useToast } from '@/stores/toast'

type Marcacion = { tipo: string; capturado_en: string; offline: boolean; selfie_path?: string | null }
type Turno = {
  id: string
  inicio: string
  fin: string
  estado: string
  vigilante_id?: string
  vigilante?: { nombre: string } | null
  marcaciones: Marcacion[]
  rondas?: { estado: string }[]
}
type VigilanteTurno = {
  turno_id: string
  vigilante_id: string
  nombre: string
  telefono: string | null
  en_puesto: boolean
}
type Ayuda = {
  id: string
  canal: string
  creado_en: string
  vigilante: { nombre: string } | null
  residente: { nombre: string } | null
}

const session = useSessionStore()
const toast = useToast()
const queryClient = useQueryClient()
const esAdmin = computed(() => session.tiene('administrador'))
const esVigilante = computed(() => session.tiene('vigilante'))
const esResidente = computed(() => session.tiene('residente'))
const debeAceptar = computed(() => (esVigilante.value || esResidente.value) && !session.perfil?.aceptadoEn)

const desde = new Date()
desde.setHours(0, 0, 0, 0)
const hasta = new Date(desde)
hasta.setDate(hasta.getDate() + 1)
const hace12h = new Date(Date.now() - 12 * 60 * 60 * 1000).toISOString()
const en14dias = new Date(Date.now() + 14 * 24 * 60 * 60 * 1000).toISOString()

const turnos = useQuery({
  queryKey: ['turnos-inicio', esAdmin.value],
  enabled: computed(() => !debeAceptar.value && (esAdmin.value || esVigilante.value)),
  queryFn: async () => {
    if (esAdmin.value) await rpc('revisar_alertas')
    let consulta = supabase
      .from('turnos')
      .select('id, inicio, fin, estado, vigilante_id, vigilante:perfiles!turnos_vigilante_id_fkey(nombre), marcaciones(tipo, capturado_en, offline, selfie_path), rondas(estado)')
      .order('inicio')
    consulta = esAdmin.value
      ? consulta.lt('inicio', hasta.toISOString()).gt('fin', desde.toISOString())
      : consulta.gt('fin', hace12h).lt('inicio', en14dias)
    const { data, error } = await consulta
    if (error) throw error
    return (data ?? []) as unknown as Turno[]
  },
})

const guardias = useQuery({
  queryKey: ['vigilantes-turno'],
  enabled: computed(() => esResidente.value && !debeAceptar.value),
  queryFn: () => rpc<VigilanteTurno[]>('vigilantes_en_turno'),
})

const ayudas = useQuery({
  queryKey: ['ayudas'],
  enabled: esAdmin,
  queryFn: async () => {
    const { data, error } = await supabase
      .from('ayudas')
      .select('id, canal, creado_en, vigilante:perfiles!ayudas_vigilante_id_fkey(nombre), residente:perfiles!ayudas_residente_id_fkey(nombre)')
      .order('creado_en', { ascending: false })
      .limit(8)
    if (error) throw error
    return (data ?? []) as unknown as Ayuda[]
  },
})

type Resumen = {
  incidentes: { tipo: string; capturado_en: string }[]
  alertas: { tipo: string }[]
  ayudas: number
}

const resumen = useQuery({
  queryKey: ['resumen-admin'],
  enabled: computed(() => esAdmin.value && turnos.isFetched.value),
  queryFn: async () => {
    const inicio = new Date()
    inicio.setDate(inicio.getDate() - 6)
    inicio.setHours(0, 0, 0, 0)
    const desdeIso = inicio.toISOString()
    const [incidentes, alertasAbiertas, ayudasSemana] = await Promise.all([
      supabase.from('incidentes').select('tipo, capturado_en').gte('capturado_en', desdeIso),
      supabase.from('alertas').select('tipo').eq('leida', false),
      supabase.from('ayudas').select('id', { count: 'exact', head: true }).gte('creado_en', desdeIso),
    ])
    if (incidentes.error) throw incidentes.error
    if (alertasAbiertas.error) throw alertasAbiertas.error
    if (ayudasSemana.error) throw ayudasSemana.error
    return {
      incidentes: incidentes.data ?? [],
      alertas: alertasAbiertas.data ?? [],
      ayudas: ayudasSemana.count ?? 0,
    } satisfies Resumen
  },
})

const errores = useQuery({
  queryKey: ['bitacora-hoy'],
  enabled: esAdmin,
  queryFn: async () => {
    const desde = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString()
    const { count, error } = await supabase.from('bitacora').select('id', { count: 'exact', head: true }).gte('creado_en', desde)
    if (error) throw error
    return count ?? 0
  },
})

function claveDia(iso: string) {
  return new Intl.DateTimeFormat('en-CA', { timeZone: 'America/Bogota', year: 'numeric', month: '2-digit', day: '2-digit' }).format(new Date(iso))
}

const hoyTurnos = computed(() => (turnos.data.value ?? []).filter((turno) => turno.estado !== 'cancelado'))

const enPuesto = computed(() => {
  const ahora = Date.now()
  return hoyTurnos.value.filter((turno) => {
    const entro = marcacion(turno, 'entrada')
    const salio = marcacion(turno, 'salida')
    return entro && !salio && new Date(turno.inicio).getTime() <= ahora && new Date(turno.fin).getTime() > ahora
  })
})

const sinEntrada = computed(() => {
  const ahora = Date.now()
  return hoyTurnos.value.filter((turno) => !marcacion(turno, 'entrada') && new Date(turno.inicio).getTime() <= ahora)
})

const rondasHoy = computed(() => {
  const todas = hoyTurnos.value.flatMap((turno) => turno.rondas ?? [])
  return {
    completas: todas.filter((ronda) => ronda.estado === 'completa').length,
    total: todas.length,
  }
})

const alertasPorTipo = computed(() => {
  const conteo = new Map<string, number>()
  for (const alerta of resumen.data.value?.alertas ?? []) conteo.set(alerta.tipo, (conteo.get(alerta.tipo) ?? 0) + 1)
  return [...conteo.entries()].map(([tipo, total]) => ({ tipo, total, nombre: nombreEstado(tipo) }))
})

const barras = computed(() => {
  const hoy = claveDia(new Date().toISOString())
  const [anio, mes, dia] = hoy.split('-').map(Number)
  const conteo = new Map<string, number>()
  for (const incidente of resumen.data.value?.incidentes ?? []) {
    const clave = claveDia(incidente.capturado_en)
    conteo.set(clave, (conteo.get(clave) ?? 0) + 1)
  }
  const dias = Array.from({ length: 7 }, (_, indice) => {
    const fecha = new Date(Date.UTC(anio, mes - 1, dia - (6 - indice)))
    const clave = `${fecha.getUTCFullYear()}-${String(fecha.getUTCMonth() + 1).padStart(2, '0')}-${String(fecha.getUTCDate()).padStart(2, '0')}`
    return {
      clave,
      total: conteo.get(clave) ?? 0,
      etiqueta: fecha.toLocaleDateString('es-CO', { day: 'numeric', month: 'short', timeZone: 'UTC' }),
    }
  })
  const maximo = Math.max(1, ...dias.map((item) => item.total))
  return dias.map((item) => ({ ...item, alto: item.total ? `${Math.max(18, Math.round((item.total / maximo) * 100))}%` : '0%' }))
})

const incidentesPorTipo = computed(() => {
  const conteo = new Map<string, number>()
  for (const incidente of resumen.data.value?.incidentes ?? []) conteo.set(incidente.tipo, (conteo.get(incidente.tipo) ?? 0) + 1)
  return [...conteo.entries()].map(([tipo, total]) => ({ tipo, total, nombre: nombreEstado(tipo) }))
})

function marcacion(turno: Turno, tipo: string) {
  return turno.marcaciones.find((item) => item.tipo === tipo)
}

function esHoy(iso: string) {
  const formato = new Intl.DateTimeFormat('en-CA', { timeZone: 'America/Bogota', year: 'numeric', month: '2-digit', day: '2-digit' })
  return formato.format(new Date(iso)) === formato.format(new Date())
}

function textoHora(item: Marcacion | undefined) {
  if (!item) return 'Pendiente'
  return fechaHora(item.capturado_en)
}

async function aceptar() {
  try {
    await rpc('aceptar_datos')
    await session.cargarPerfil()
    await queryClient.invalidateQueries()
    toast.ok('Quedó registrado el tratamiento de datos.')
  } catch (error) {
    toast.error(mensajeError(error))
  }
}

async function ayudar(vigilanteId: string, canal: 'llamada' | 'mensaje') {
  try {
    const data = await rpc<{ telefono: string; nombre: string }>('registrar_ayuda', { vigilante_id: vigilanteId, canal })
    const numero = telefonoWhatsapp(data.telefono)
    if (canal === 'llamada') window.location.href = `tel:+${numero}`
    else window.open(`https://wa.me/${numero}?text=${encodeURIComponent('Hola, necesito apoyo de la vigilancia.')}`, '_blank', 'noopener')
  } catch (error) {
    toast.error(mensajeError(error))
  }
}
</script>

<template>
  <section>
    <div v-if="debeAceptar" class="max-w-xl rounded-3xl bg-white p-5">
      <h1 class="text-2xl font-semibold tracking-tight">Tratamiento de datos</h1>
      <p class="mt-3 text-sm leading-relaxed text-slate-700">
        Acepto que el conjunto trate mi nombre, mi teléfono y, si soy vigilante, las fotos de entrada, rondas e incidentes, solo para el control de la vigilancia. La política definitiva la define la administración con un abogado.
      </p>
      <Boton class="mt-4" @click="aceptar">Acepto</Boton>
    </div>

    <template v-else-if="esVigilante && !esAdmin">
      <div class="flex flex-wrap items-end justify-between gap-3">
        <div>
          <h1 class="text-3xl font-semibold tracking-tight">Mis turnos</h1>
        </div>
        <RouterLink to="/calendario" class="inline-flex min-h-10 items-center rounded-xl bg-white px-3 text-sm font-semibold ring-1 ring-slate-200">Ver calendario</RouterLink>
      </div>
      <PantallaCarga v-if="turnos.isLoading.value" />
      <p v-else-if="(turnos.data.value ?? []).length === 0" class="mt-4 text-sm text-slate-500">No tienes turnos cercanos. El administrador te los asigna.</p>
      <ul v-else class="mt-4 space-y-3">
        <li v-for="turno in turnos.data.value" :key="turno.id" class="rounded-3xl bg-white p-4">
          <p class="text-sm text-slate-500">{{ fechaHora(turno.inicio) }} – {{ fechaHora(turno.fin) }}</p>
          <p class="mt-1 font-semibold">{{ nombreEstado(turno.estado) }}</p>
          <p class="mt-2 text-sm text-slate-600">Entrada: {{ textoHora(marcacion(turno, 'entrada')) }}</p>
          <p class="text-sm text-slate-600">Salida: {{ textoHora(marcacion(turno, 'salida')) }}</p>
          <div class="mt-4 flex flex-wrap gap-2">
            <RouterLink v-if="!marcacion(turno, 'entrada') && esHoy(turno.inicio)" :to="`/marcar/${turno.id}?tipo=entrada`" class="btn-shine inline-flex min-h-12 items-center rounded-xl bg-marca px-4 text-sm font-semibold text-white">Marcar entrada</RouterLink>
            <RouterLink v-if="marcacion(turno, 'entrada') && !marcacion(turno, 'salida')" :to="`/ronda/${turno.id}`" class="inline-flex min-h-12 items-center rounded-xl bg-slate-900 px-4 text-sm font-semibold text-white">Hacer ronda</RouterLink>
            <RouterLink v-if="marcacion(turno, 'entrada') && !marcacion(turno, 'salida')" :to="`/marcar/${turno.id}?tipo=salida`" class="inline-flex min-h-12 items-center rounded-xl bg-white px-4 text-sm font-semibold ring-1 ring-slate-200">Marcar salida</RouterLink>
          </div>
        </li>
      </ul>
    </template>

    <template v-else-if="esResidente && !esAdmin">
      <h1 class="text-3xl font-semibold tracking-tight">Vigilancia de turno</h1>
      <PantallaCarga v-if="guardias.isLoading.value" />
      <p v-else-if="(guardias.data.value ?? []).length === 0" class="mt-4 text-sm text-slate-500">En este momento no hay un vigilante asignado.</p>
      <ul v-else class="mt-4 space-y-3">
        <li v-for="guardia in guardias.data.value" :key="guardia.turno_id" class="rounded-3xl bg-white p-4">
          <p class="text-lg font-semibold">{{ guardia.nombre }}</p>
          <p class="text-sm text-slate-600">{{ guardia.en_puesto ? 'Ya marcó entrada' : 'Turno asignado, sin entrada marcada' }}</p>
          <p class="mt-1 text-sm text-slate-600">{{ guardia.telefono || 'Sin teléfono' }}</p>
          <div class="mt-4 flex flex-wrap gap-2">
            <Boton :disabled="!guardia.telefono" @click="ayudar(guardia.vigilante_id, 'llamada')">Llamar</Boton>
            <Boton variante="secundario" :disabled="!guardia.telefono" @click="ayudar(guardia.vigilante_id, 'mensaje')">Mensaje</Boton>
          </div>
        </li>
      </ul>
    </template>

    <template v-else-if="esAdmin">
      <h1 class="text-3xl font-semibold tracking-tight">Hoy</h1>
      <PantallaCarga v-if="turnos.isLoading.value" />
      <div v-else class="mt-4 grid gap-3 sm:grid-cols-2 xl:grid-cols-4">
        <article class="rounded-3xl bg-white p-4">
          <p class="text-sm text-slate-500">En puesto</p>
          <p class="mt-1 text-3xl font-semibold tracking-tight">{{ enPuesto.length }}</p>
          <p class="mt-2 text-sm text-slate-600">{{ enPuesto.map((turno) => turno.vigilante?.nombre).filter(Boolean).join(', ') || 'Nadie' }}</p>
        </article>
        <article class="rounded-3xl bg-white p-4">
          <p class="text-sm text-slate-500">Sin entrada</p>
          <p class="mt-1 text-3xl font-semibold tracking-tight">{{ sinEntrada.length }}</p>
          <p class="mt-2 text-sm text-slate-600">{{ sinEntrada.map((turno) => turno.vigilante?.nombre).filter(Boolean).join(', ') || 'Al día' }}</p>
        </article>
        <article class="rounded-3xl bg-white p-4">
          <p class="text-sm text-slate-500">Rondas de hoy</p>
          <p class="mt-1 text-3xl font-semibold tracking-tight">
            <template v-if="rondasHoy.total">{{ rondasHoy.completas }}<span class="text-lg text-slate-400">/{{ rondasHoy.total }}</span></template>
            <template v-else>0</template>
          </p>
          <p class="mt-2 text-sm text-slate-600">{{ rondasHoy.total ? 'Completas' : 'Sin iniciar' }}</p>
        </article>
        <RouterLink to="/alertas" class="rounded-3xl bg-white p-4">
          <p class="text-sm text-slate-500">Alertas sin leer</p>
          <p class="mt-1 text-3xl font-semibold tracking-tight">{{ resumen.data.value?.alertas.length ?? 0 }}</p>
          <p class="mt-2 text-sm text-slate-600">{{ alertasPorTipo.map((fila) => `${fila.total} ${fila.nombre}`).join(' · ') || 'Nada pendiente' }}</p>
        </RouterLink>
        <RouterLink to="/bitacora" class="rounded-3xl bg-white p-4">
          <p class="text-sm text-slate-500">Errores del celular</p>
          <p class="mt-1 text-3xl font-semibold tracking-tight">{{ errores.data.value ?? 0 }}</p>
          <p class="mt-2 text-sm text-slate-600">Últimas 24 horas</p>
        </RouterLink>
      </div>
      <div v-if="!turnos.isLoading.value" class="mt-3 grid gap-3 lg:grid-cols-[1.4fr_0.8fr]">
        <section class="rounded-3xl bg-white p-4">
          <div class="flex items-baseline justify-between gap-3">
            <h2 class="text-lg font-semibold">Incidentes</h2>
            <RouterLink to="/incidentes" class="text-sm font-semibold text-marca">Ver</RouterLink>
          </div>
          <p class="mt-1 text-sm text-slate-500">{{ resumen.data.value?.incidentes.length ?? 0 }} en 7 días</p>
          <PantallaCarga v-if="resumen.isLoading.value" />
          <div v-else class="mt-4 flex h-32 items-end gap-2">
            <div v-for="dia in barras" :key="dia.clave" class="flex h-full min-w-0 flex-1 flex-col justify-end gap-1">
              <span class="text-center text-[11px] font-semibold text-slate-500">{{ dia.total || '' }}</span>
              <div class="flex h-20 items-end rounded-lg bg-slate-100">
                <div class="w-full rounded-lg bg-marca" :style="{ height: dia.alto }" />
              </div>
              <span class="truncate text-center text-[10px] text-slate-500">{{ dia.etiqueta }}</span>
            </div>
          </div>
          <p v-if="incidentesPorTipo.length" class="mt-3 text-sm text-slate-600">{{ incidentesPorTipo.map((fila) => `${fila.total} ${fila.nombre}`).join(' · ') }}</p>
        </section>
        <section class="rounded-3xl bg-white p-4">
          <h2 class="text-lg font-semibold">Ayuda de residentes</h2>
          <p class="mt-1 text-3xl font-semibold tracking-tight">{{ resumen.data.value?.ayudas ?? 0 }}</p>
          <p class="text-sm text-slate-500">Pedidos en 7 días</p>
        </section>
      </div>
      <h2 v-if="!turnos.isLoading.value" class="mt-8 text-xl font-semibold">Turnos de hoy</h2>
      <ul v-if="!turnos.isLoading.value" class="mt-4 space-y-3">
        <li v-for="turno in turnos.data.value ?? []" :key="turno.id" class="rounded-3xl bg-white p-4">
          <p class="font-semibold">{{ turno.vigilante?.nombre }} · {{ nombreEstado(turno.estado) }}</p>
          <p class="text-sm text-slate-500">{{ fechaHora(turno.inicio) }} – {{ fechaHora(turno.fin) }}</p>
          <p class="mt-2 text-sm">Entrada: {{ textoHora(marcacion(turno, 'entrada')) }}</p>
          <p class="text-sm">Salida: {{ textoHora(marcacion(turno, 'salida')) }}</p>
          <p class="text-sm text-slate-600">Rondas: {{ (turno.rondas ?? []).map((ronda) => nombreEstado(ronda.estado)).join(', ') || 'Sin iniciar' }}</p>
          <FotoPrivada class="mt-3" :path="marcacion(turno, 'entrada')?.selfie_path" alt="Selfie de entrada" />
          <RouterLink :to="`/qr/caseta/${turno.id}`" class="mt-3 inline-flex text-sm font-semibold text-marca">Imprimir QR de caseta</RouterLink>
        </li>
      </ul>
      <h2 class="mt-8 text-xl font-semibold">Pedidos de ayuda</h2>
      <ul class="mt-3 space-y-2">
        <li v-for="ayuda in ayudas.data.value ?? []" :key="ayuda.id" class="rounded-2xl bg-white px-4 py-3 text-sm">
          {{ ayuda.residente?.nombre }} · {{ nombreEstado(ayuda.canal) }} a {{ ayuda.vigilante?.nombre }} · {{ fechaHora(ayuda.creado_en) }}
        </li>
        <li v-if="(ayudas.data.value ?? []).length === 0" class="text-sm text-slate-500">Todavía no hay pedidos.</li>
      </ul>
    </template>
  </section>
</template>
