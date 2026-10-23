<script setup lang="ts">
import { useOnline } from '@vueuse/core'
import { Bell, Calendar, CalendarClock, House, LogOut, MapPin, Menu, ShieldAlert, Siren, Smartphone, Users, X } from 'lucide-vue-next'
import { computed, onMounted, ref, watch } from 'vue'
import { RouterLink, RouterView, useRoute, useRouter } from 'vue-router'
import PantallaCarga from '@/components/PantallaCarga.vue'
import { pendientes, refrescarConteo, sincronizar } from '@/lib/cola'
import { useSessionStore } from '@/stores/session'

const session = useSessionStore()
const route = useRoute()
const router = useRouter()
const enLinea = useOnline()
const menuAbierto = ref(false)

const enlaces = computed(() => {
  const admin = session.tiene('administrador')
  const vigilante = session.tiene('vigilante')
  const items = [
    { to: '/', nombre: 'Inicio', icono: House, visible: true },
    { to: '/calendario', nombre: 'Calendario', icono: Calendar, visible: vigilante },
    { to: '/incidentes/nuevo', nombre: 'Incidente', icono: Siren, visible: vigilante },
    { to: '/cola', nombre: pendientes.value > 0 ? `Pendientes (${pendientes.value})` : 'Pendientes', icono: Smartphone, visible: vigilante },
    { to: '/turnos', nombre: 'Turnos', icono: CalendarClock, visible: admin },
    { to: '/puntos', nombre: 'Puntos', icono: MapPin, visible: admin },
    { to: '/ventanas', nombre: 'Ventanas', icono: CalendarClock, visible: admin },
    { to: '/incidentes', nombre: 'Incidentes', icono: Siren, visible: admin },
    { to: '/alertas', nombre: 'Alertas', icono: Bell, visible: admin },
    { to: '/conjunto', nombre: 'Conjunto', icono: ShieldAlert, visible: admin },
    { to: '/usuarios', nombre: 'Usuarios', icono: Users, visible: admin },
  ]
  return items.filter((item) => item.visible)
})

const movil = computed(() => enlaces.value.slice(0, 4))

watch(
  () => route.path,
  () => {
    menuAbierto.value = false
  },
)

watch(enLinea, (linea) => {
  if (linea && session.tiene('vigilante')) void sincronizar()
})

onMounted(() => {
  if (session.tiene('vigilante')) {
    void refrescarConteo()
    if (enLinea.value) void sincronizar()
  }
})

function activo(to: string) {
  if (to === '/') return route.path === '/'
  return route.path === to || route.path.startsWith(`${to}/`)
}

async function salir() {
  await session.salir()
  await router.push({ name: 'login' })
}
</script>

<template>
  <div class="min-h-dvh bg-[#eef2f6] md:grid md:grid-cols-[240px_1fr]">
    <aside class="no-print sticky top-0 hidden h-dvh flex-col overflow-hidden bg-ink text-white md:flex">
      <div class="pointer-events-none absolute inset-0 overflow-hidden" aria-hidden="true">
        <div class="absolute -top-10 left-0 h-40 w-40 rounded-full bg-oro/25 blur-3xl" />
      </div>
      <RouterLink to="/" class="relative flex shrink-0 items-center gap-3 px-5 py-5">
        <span class="grid size-10 place-items-center rounded-2xl border border-white/10 bg-white/10">
          <ShieldAlert class="size-5 text-oro" aria-hidden="true" />
        </span>
        <span>
          <span class="block text-sm font-semibold tracking-tight">Vigilancia</span>
          <span class="block text-xs text-white/60">Conjunto</span>
        </span>
      </RouterLink>
      <nav class="relative flex min-h-0 flex-1 flex-col gap-1 overflow-y-auto px-3" aria-label="Principal">
        <RouterLink
          v-for="enlace in enlaces"
          :key="enlace.to"
          :to="enlace.to"
          class="flex min-h-11 shrink-0 items-center gap-3 rounded-xl px-3 text-sm font-medium text-white/75 transition hover:bg-white/10 hover:text-white"
          :class="activo(enlace.to) ? 'bg-white/10 text-white shadow-[inset_3px_0_0_#dc9f22]' : ''"
          :aria-current="activo(enlace.to) ? 'page' : undefined"
        >
          <component :is="enlace.icono" class="size-4" aria-hidden="true" />
          {{ enlace.nombre }}
        </RouterLink>
      </nav>
      <div class="relative shrink-0 border-t border-white/10 p-4">
        <RouterLink to="/perfil" class="block truncate text-sm font-medium">{{ session.nombre }}</RouterLink>
        <button type="button" class="mt-3 inline-flex items-center gap-2 text-sm text-white/70" @click="salir">
          <LogOut class="size-4" aria-hidden="true" /> Salir
        </button>
      </div>
    </aside>

    <div class="min-w-0">
      <header class="no-print sticky top-0 z-40 flex items-center gap-2 bg-marca px-2 py-2 text-white md:hidden">
        <button
          type="button"
          class="grid size-11 place-items-center rounded-xl hover:bg-white/10"
          :aria-expanded="menuAbierto"
          aria-controls="menu-movil"
          @click="menuAbierto = !menuAbierto"
        >
          <X v-if="menuAbierto" class="size-5" aria-hidden="true" />
          <Menu v-else class="size-5" aria-hidden="true" />
          <span class="sr-only">{{ menuAbierto ? 'Cerrar menú' : 'Abrir menú' }}</span>
        </button>
        <RouterLink to="/" class="text-sm font-semibold tracking-tight">Vigilancia</RouterLink>
      </header>
      <div v-if="menuAbierto" class="no-print fixed inset-0 z-[35] md:hidden">
        <button type="button" class="absolute inset-0 bg-ink/45" aria-label="Cerrar menú" @click="menuAbierto = false" />
        <nav id="menu-movil" class="absolute inset-y-0 left-0 flex w-[min(100%,18rem)] flex-col bg-marca pt-16 text-white shadow-2xl" aria-label="Todas las secciones">
          <div class="min-h-0 flex-1 space-y-1 overflow-y-auto px-3 pb-4">
            <RouterLink
              v-for="enlace in enlaces"
              :key="enlace.to"
              :to="enlace.to"
              class="flex min-h-11 items-center gap-3 rounded-xl px-3 text-sm font-medium text-white/80"
              :class="activo(enlace.to) ? 'bg-white/10 text-white shadow-[inset_3px_0_0_#dc9f22]' : ''"
              :aria-current="activo(enlace.to) ? 'page' : undefined"
            >
              <component :is="enlace.icono" class="size-4" aria-hidden="true" />
              {{ enlace.nombre }}
            </RouterLink>
          </div>
          <div class="shrink-0 border-t border-white/10 p-4 pb-[max(1rem,env(safe-area-inset-bottom))]">
            <RouterLink to="/perfil" class="block truncate text-sm font-medium">{{ session.nombre }}</RouterLink>
            <button type="button" class="mt-3 inline-flex min-h-11 items-center gap-2 text-sm text-white/75" @click="salir">
              <LogOut class="size-4" aria-hidden="true" /> Salir
            </button>
          </div>
        </nav>
      </div>
      <p v-if="!enLinea" class="no-print bg-amber-100 px-4 py-2 text-sm text-amber-950" role="status">Sin conexión.</p>
      <main class="w-full px-3 py-3 pb-24 sm:px-4 md:px-5 md:py-4 md:pb-6">
        <RouterView v-slot="{ Component }">
          <Suspense>
            <component :is="Component" />
            <template #fallback>
              <PantallaCarga />
            </template>
          </Suspense>
        </RouterView>
      </main>
    </div>

    <nav class="no-print fixed inset-x-0 bottom-0 z-30 border-t border-slate-200/80 bg-white/85 px-2 pb-[env(safe-area-inset-bottom)] backdrop-blur-xl md:hidden" aria-label="Móvil">
      <ul class="grid" :style="{ gridTemplateColumns: `repeat(${movil.length}, minmax(0, 1fr))` }">
        <li v-for="enlace in movil" :key="enlace.to">
          <RouterLink
            :to="enlace.to"
            class="flex min-h-14 flex-col items-center justify-center gap-1 text-[11px] font-medium text-slate-500"
            :class="activo(enlace.to) ? 'text-marca' : ''"
            :aria-current="activo(enlace.to) ? 'page' : undefined"
          >
            <component :is="enlace.icono" class="size-5" aria-hidden="true" />
            {{ enlace.nombre }}
          </RouterLink>
        </li>
      </ul>
    </nav>
  </div>
</template>
