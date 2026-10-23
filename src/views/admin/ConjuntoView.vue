<script setup lang="ts">
import { useQuery, useQueryClient } from '@tanstack/vue-query'
import InputText from 'primevue/inputtext'
import { ref, watch } from 'vue'
import { useRouter } from 'vue-router'
import Boton from '@/components/Boton.vue'
import PantallaCarga from '@/components/PantallaCarga.vue'
import Campo from '@/components/Campo.vue'
import NumeroCampo from '@/components/NumeroCampo.vue'
import { rpc } from '@/lib/api'
import { mensajeError } from '@/lib/domain'
import { ubicacionActual } from '@/lib/geo'
import { useToast } from '@/stores/toast'

type Conjunto = { nombre: string; lat: number | null; lng: number | null; radio_m: number }

const toast = useToast()
const router = useRouter()
const queryClient = useQueryClient()
const nombre = ref('')
const lat = ref('')
const lng = ref('')
const radio = ref<number | null>(100)
const guardando = ref(false)

const conjunto = useQuery({
  queryKey: ['conjunto'],
  queryFn: () => rpc<Conjunto>('datos_conjunto'),
})

watch(conjunto.data, (fila) => {
  if (!fila) return
  nombre.value = fila.nombre
  lat.value = fila.lat == null ? '' : String(fila.lat)
  lng.value = fila.lng == null ? '' : String(fila.lng)
  radio.value = fila.radio_m
})

async function usarAqui() {
  try {
    const punto = await ubicacionActual()
    lat.value = String(punto.lat)
    lng.value = String(punto.lng)
    toast.ok('Ubicación leída una vez. Guárdala si estás en la caseta.')
  } catch (error) {
    toast.error(mensajeError(error))
  }
}

async function rotar() {
  guardando.value = true
  try {
    await rpc('rotar_caseta')
    toast.ok('El QR anterior ya no sirve. Imprime este.')
    await router.push('/qr/caseta')
  } catch (error) {
    toast.error(mensajeError(error))
  } finally {
    guardando.value = false
  }
}

async function guardar() {
  guardando.value = true
  try {
    await rpc('guardar_conjunto', {
      nombre: nombre.value,
      lat: Number(lat.value),
      lng: Number(lng.value),
      radio_m: radio.value ?? 100,
    })
    toast.ok('Conjunto actualizado.')
    await queryClient.invalidateQueries({ queryKey: ['conjunto'] })
  } catch (error) {
    toast.error(mensajeError(error))
  } finally {
    guardando.value = false
  }
}
</script>

<template>
  <section class="max-w-xl">
    <h1 class="text-3xl font-semibold tracking-tight">Conjunto</h1>
    <PantallaCarga v-if="conjunto.isLoading.value || guardando" :fija="guardando" />
    <form v-else class="mt-4 space-y-3" @submit.prevent="guardar">
      <Campo etiqueta="Nombre"><InputText v-model="nombre" /></Campo>
      <Campo etiqueta="Latitud"><InputText v-model="lat" /></Campo>
      <Campo etiqueta="Longitud"><InputText v-model="lng" /></Campo>
      <Campo etiqueta="Radio en metros" ayuda="100 m. El escaneo solo pasa dentro de este radio."><NumeroCampo v-model="radio" :min="30" :max="1000" /></Campo>
      <div class="flex flex-wrap gap-2">
        <Boton variante="secundario" @click="usarAqui">Usar donde estoy</Boton>
        <Boton tipo="submit" :disabled="guardando">Guardar</Boton>
      </div>
    </form>
    <div v-if="!conjunto.isLoading.value" class="mt-6 flex flex-wrap gap-3 text-sm">
      <RouterLink to="/qr/caseta" class="font-semibold text-marca">Imprimir QR de la caseta</RouterLink>
      <button type="button" class="font-semibold" :disabled="guardando" @click="rotar">Invalidar QR</button>
    </div>
  </section>
</template>
