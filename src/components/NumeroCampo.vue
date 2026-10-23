<script setup lang="ts">
import InputNumber from 'primevue/inputnumber'

withDefaults(defineProps<{ min?: number; max?: number }>(), { min: 1, max: 1000 })

const model = defineModel<number | null>({ default: null })
</script>

<template>
  <InputNumber v-model="model" :min="min" :max="max" :use-grouping="false" />
</template>
