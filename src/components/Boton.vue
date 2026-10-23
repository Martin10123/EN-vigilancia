<script setup lang="ts">
import Button from 'primevue/button'
import { computed } from 'vue'
import { botonClase } from '@/prime'

const props = withDefaults(
  defineProps<{
    variante?: keyof typeof botonClase
    tipo?: 'button' | 'submit'
    disabled?: boolean
  }>(),
  { variante: 'primario', tipo: 'button', disabled: false },
)

const clase = computed(() => botonClase[props.variante])
</script>

<template>
  <Button :type="tipo" :disabled="disabled" :pt="{ root: clase }">
    <slot />
  </Button>
</template>
