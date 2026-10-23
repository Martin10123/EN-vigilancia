<script setup lang="ts">
const props = defineProps<{
  clave: 'gps' | 'hash' | 'offline' | 'ayuda'
}>()

const textos = {
  gps: 'La ubicación se lee una sola vez, en este registro. No se guarda un recorrido. El GPS del navegador se puede simular: el QR, la selfie y la hora del servidor dificultan el fraude, pero no prueban que la persona esté físicamente en el lugar.',
  hash: 'El hash detecta si el archivo guardado cambió después. No prueba que la foto sea del lugar.',
  offline: 'Si no hay datos, el registro queda en este celular. La hora que verá el administrador es la de la sincronización, no la hora del teléfono.',
  ayuda: 'Este botón llama o escribe al vigilante de turno. No reemplaza al 123 ni garantiza una respuesta.',
}
</script>

<template>
  <p class="rounded-2xl bg-amber-50 px-3 py-2 text-sm text-amber-950">{{ textos[props.clave] }}</p>
</template>
