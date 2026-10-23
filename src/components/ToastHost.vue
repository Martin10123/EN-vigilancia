<script setup lang="ts">
import { useToast } from '@/stores/toast'

const toast = useToast()
</script>

<template>
  <div class="pointer-events-none fixed inset-x-0 top-3 z-50 flex flex-col items-center gap-2 px-4" aria-live="polite">
    <p
      v-for="aviso in toast.avisos.value"
      :key="aviso.id"
      class="pointer-events-auto w-full max-w-md rounded-2xl px-4 py-3 text-sm font-medium shadow-2xl"
      :class="aviso.tipo === 'ok' ? 'bg-marca text-white' : 'bg-rose-800 text-white'"
      role="status"
    >
      {{ aviso.texto }}
    </p>
  </div>
</template>
