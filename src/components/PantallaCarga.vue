<script setup lang="ts">
defineProps<{ fija?: boolean }>()
</script>

<template>
  <div
    class="grid place-items-center"
    :class="fija ? 'fixed inset-0 z-[80] bg-[#eef2f6]/92 backdrop-blur-sm' : 'min-h-[40dvh]'"
    role="status"
    aria-live="polite"
  >
    <div class="flex flex-col items-center gap-3">
      <span class="size-11 rounded-full border-4 border-slate-200 border-t-marca motion-safe:animate-spin" aria-hidden="true" />
      <span class="text-sm font-semibold text-slate-600">Cargando</span>
    </div>
  </div>
</template>
