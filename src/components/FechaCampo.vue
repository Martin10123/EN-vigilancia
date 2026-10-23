<script setup lang="ts">
import { Calendar } from 'lucide-vue-next'
import DatePicker from 'primevue/datepicker'
import { computed } from 'vue'

const model = defineModel<string>({ default: '' })

const valor = computed<Date | null>({
  get() {
    if (!/^\d{4}-\d{2}-\d{2}/.test(model.value)) return null
    const [anio, mes, dia] = model.value.slice(0, 10).split('-').map(Number)
    return new Date(anio, mes - 1, dia)
  },
  set(fecha) {
    if (!(fecha instanceof Date) || Number.isNaN(fecha.getTime())) {
      model.value = ''
      return
    }
    const mes = String(fecha.getMonth() + 1).padStart(2, '0')
    const dia = String(fecha.getDate()).padStart(2, '0')
    model.value = `${fecha.getFullYear()}-${mes}-${dia}`
  },
})
</script>

<template>
  <DatePicker v-model="valor" date-format="dd/mm/yy" show-icon icon-display="input" show-button-bar append-to="body" placeholder="dd/mm/aaaa">
    <template #inputicon="{ clickCallback }">
      <Calendar class="size-4" aria-hidden="true" @click="clickCallback" />
    </template>
  </DatePicker>
</template>
