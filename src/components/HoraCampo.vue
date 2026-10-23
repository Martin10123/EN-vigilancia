<script setup lang="ts">
import { Clock } from 'lucide-vue-next'
import DatePicker from 'primevue/datepicker'
import { computed } from 'vue'

const model = defineModel<string>({ default: '' })

const valor = computed<Date | null>({
  get() {
    if (!/^\d{2}:\d{2}/.test(model.value)) return null
    const [hora, minuto] = model.value.slice(0, 5).split(':').map(Number)
    const fecha = new Date()
    fecha.setHours(hora, minuto, 0, 0)
    return fecha
  },
  set(fecha) {
    if (!(fecha instanceof Date) || Number.isNaN(fecha.getTime())) {
      model.value = ''
      return
    }
    model.value = `${String(fecha.getHours()).padStart(2, '0')}:${String(fecha.getMinutes()).padStart(2, '0')}`
  },
})
</script>

<template>
  <DatePicker v-model="valor" time-only hour-format="12" show-icon icon-display="input" append-to="body" placeholder="hh:mm">
    <template #inputicon="{ clickCallback }">
      <Clock class="size-4" aria-hidden="true" @click="clickCallback" />
    </template>
  </DatePicker>
</template>
