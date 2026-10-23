<script setup lang="ts">
import { useQuery } from '@tanstack/vue-query'
import { computed } from 'vue'
import { urlFirmada } from '@/lib/media'

const props = defineProps<{
  path: string | null | undefined
  alt: string
}>()

const ruta = computed(() => props.path ?? '')
const { data, isLoading, isError } = useQuery({
  queryKey: computed(() => ['archivo', ruta.value]),
  enabled: computed(() => ruta.value.length > 0),
  staleTime: 8 * 60 * 1000,
  queryFn: () => urlFirmada(ruta.value),
})
</script>

<template>
  <div v-if="path" class="overflow-hidden rounded-xl border border-slate-200 bg-slate-50">
    <p v-if="isLoading" class="px-3 py-6 text-sm text-slate-500">Cargando evidencia…</p>
    <p v-else-if="isError" class="px-3 py-6 text-sm text-rose-700">No se pudo abrir la foto.</p>
    <img v-else-if="data" :src="data" :alt="alt" class="max-h-64 w-full object-contain" />
  </div>
</template>
