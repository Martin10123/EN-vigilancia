<script setup lang="ts">
import { Calendar } from 'lucide-vue-next'
import DatePicker from 'primevue/datepicker'

const model = defineModel<Date | null>({ default: null })
</script>

<template>
  <DatePicker
    v-model="model"
    show-time
    hour-format="12"
    date-format="dd/mm/yy"
    show-icon
    icon-display="input"
    append-to="body"
    placeholder="dd/mm/aaaa hh:mm"
  >
    <template #inputicon="{ clickCallback }">
      <Calendar class="size-4" aria-hidden="true" @click="clickCallback" />
    </template>
  </DatePicker>
</template>
