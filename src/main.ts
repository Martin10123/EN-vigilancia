import { VueQueryPlugin, QueryClient } from '@tanstack/vue-query'
import { createPinia } from 'pinia'
import PrimeVue from 'primevue/config'
import { createApp } from 'vue'
import App from './App.vue'
import { anotar } from './lib/bitacora'
import { mensajeError } from './lib/domain'
import { primePt } from './prime'
import router from './router'
import './style.css'

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 15_000,
      gcTime: 1000 * 60 * 30,
      refetchOnWindowFocus: true,
      retry: 1,
    },
  },
})

const app = createApp(App)
app.config.errorHandler = (error) => {
  anotar(mensajeError(error), error instanceof Error ? error.stack : undefined, 'pantalla')
}
app.use(createPinia())
app.use(router)
  .use(VueQueryPlugin, { queryClient })
  .use(PrimeVue, {
    unstyled: true,
    pt: primePt,
    ptOptions: { mergeSections: true, mergeProps: true },
    locale: {
      firstDayOfWeek: 1,
      dayNames: ['domingo', 'lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado'],
      dayNamesShort: ['dom', 'lun', 'mar', 'mié', 'jue', 'vie', 'sáb'],
      dayNamesMin: ['D', 'L', 'M', 'X', 'J', 'V', 'S'],
      monthNames: ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'],
      monthNamesShort: ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'],
      today: 'Hoy',
      clear: 'Limpiar',
    },
  })
app.mount('#app')

window.addEventListener('unhandledrejection', (evento) => {
  anotar(mensajeError(evento.reason), undefined, 'promesa')
})
