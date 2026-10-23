<script setup lang="ts">
import { useQuery, useQueryClient } from '@tanstack/vue-query'
import { computed } from 'vue'
import { RouterLink } from 'vue-router'
import AvisoLimite from '@/components/AvisoLimite.vue'
import Boton from '@/components/Boton.vue'
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
      : consulta.gt('fin', hace12h)
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

const alertas = useQuery({
  queryKey: ['alertas-abiertas'],
  enabled: esAdmin,
  queryFn: async () => {
    const { count, error } = await supabase.from('alertas').select('id', { count: 'exact', head: true }).eq('leida', false)
    if (error) throw error
    return count ?? 0
  },
})

function marcacion(turno: Turno, tipo: string) {
  return turno.marcaciones.find((item) => item.tipo === tipo)
}

function textoHora(item: Marcacion | undefined) {
  if (!item) return 'Pendiente'
  const hora = fechaHora(item.capturado_en)
  return item.offline ? `${hora} · hora de sincronización, capturado sin conexión` : `${hora} · hora del servidor`
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
      <h1 class="text-3xl font-semibold tracking-tight">Mis turnos</h1>
      <p class="mt-2 text-sm text-slate-600">Marca la entrada al llegar, haz las dos rondas y reporta lo que pase. Cada paso pide el QR del lugar.</p>
      <AvisoLimite clave="offline" class="mt-4" />
      <p v-if="turnos.isLoading.value" class="mt-4 text-sm text-slate-500">Cargando…</p>
      <p v-else-if="(turnos.data.value ?? []).length === 0" class="mt-4 text-sm text-slate-500">No tienes turnos cercanos. El administrador te los asigna.</p>
      <ul v-else class="mt-4 space-y-3">
        <li v-for="turno in turnos.data.value" :key="turno.id" class="rounded-3xl bg-white p-4">
          <p class="text-sm text-slate-500">{{ fechaHora(turno.inicio) }} – {{ fechaHora(turno.fin) }}</p>
          <p class="mt-1 font-semibold">{{ nombreEstado(turno.estado) }}</p>
          <p class="mt-2 text-sm text-slate-600">Entrada: {{ textoHora(marcacion(turno, 'entrada')) }}</p>
          <p class="text-sm text-slate-600">Salida: {{ textoHora(marcacion(turno, 'salida')) }}</p>
          <div class="mt-4 flex flex-wrap gap-2">
            <RouterLink v-if="!marcacion(turno, 'entrada')" :to="`/marcar/${turno.id}?tipo=entrada`" class="btn-shine inline-flex min-h-12 items-center rounded-xl bg-marca px-4 text-sm font-semibold text-white">Marcar entrada</RouterLink>
            <RouterLink v-if="marcacion(turno, 'entrada') && !marcacion(turno, 'salida')" :to="`/ronda/${turno.id}`" class="inline-flex min-h-12 items-center rounded-xl bg-slate-900 px-4 text-sm font-semibold text-white">Hacer ronda</RouterLink>
            <RouterLink v-if="marcacion(turno, 'entrada') && !marcacion(turno, 'salida')" :to="`/marcar/${turno.id}?tipo=salida`" class="inline-flex min-h-12 items-center rounded-xl bg-white px-4 text-sm font-semibold ring-1 ring-slate-200">Marcar salida</RouterLink>
          </div>
        </li>
      </ul>
    </template>

    <template v-else-if="esResidente && !esAdmin">
      <h1 class="text-3xl font-semibold tracking-tight">Vigilancia de turno</h1>
      <AvisoLimite clave="ayuda" class="mt-4" />
      <p v-if="guardias.isLoading.value" class="mt-4 text-sm text-slate-500">Cargando…</p>
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
      <div class="flex flex-wrap items-end justify-between gap-3">
        <div>
          <h1 class="text-3xl font-semibold tracking-tight">Hoy</h1>
          <p class="mt-2 text-sm text-slate-600">Quién está de turno, si marcó y si la ronda quedó completa.</p>
        </div>
        <RouterLink to="/alertas" class="inline-flex min-h-10 items-center rounded-xl bg-white px-3 text-sm font-semibold ring-1 ring-slate-200">
          Alertas sin leer: {{ alertas.data.value ?? 0 }}
        </RouterLink>
      </div>
      <p v-if="turnos.isLoading.value" class="mt-4 text-sm text-slate-500">Cargando…</p>
      <ul v-else class="mt-4 space-y-3">
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
