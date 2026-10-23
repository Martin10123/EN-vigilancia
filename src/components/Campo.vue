<script setup lang="ts">
defineProps<{
  etiqueta: string
  ayuda?: string
}>()
</script>

<template>
  <label class="block">
    <span class="mb-1 block text-sm font-medium tracking-tight text-slate-700">{{ etiqueta }}</span>
    <slot />
    <span v-if="ayuda" class="mt-1 block text-xs text-slate-500">{{ ayuda }}</span>
  </label>
</template>
