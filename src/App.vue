<script setup lang="ts">
import { ref, watch } from 'vue'
import PantallaCarga from '@/components/PantallaCarga.vue'
import ToastHost from '@/components/ToastHost.vue'
import { navegando } from '@/router'

const visible = ref(false)
let reloj = 0
let primera = true

watch(
  navegando,
  (valor) => {
    window.clearTimeout(reloj)
    if (!valor) {
      visible.value = false
      primera = false
      return
    }
    if (primera) {
      visible.value = true
      return
    }
    reloj = window.setTimeout(() => {
      visible.value = true
    }, 180)
  },
  { immediate: true },
)
</script>

<template>
  <RouterView />
  <PantallaCarga v-if="visible" fija />
  <ToastHost />
</template>
