import { ref } from 'vue'
import { createRouter, createWebHistory } from 'vue-router'
import { supabaseConfigurado } from '@/lib/supabase'
import { useSessionStore } from '@/stores/session'

export const navegando = ref(true)

declare module 'vue-router' {
  interface RouteMeta {
    publico?: boolean
    titulo?: string
    roles?: string[]
  }
}

const router = createRouter({
  history: createWebHistory(),
  routes: [
    { path: '/login', name: 'login', component: () => import('@/views/LoginView.vue'), meta: { publico: true, titulo: 'Entrar' } },
    {
      path: '/',
      component: () => import('@/components/AppShell.vue'),
      children: [
        { path: '', name: 'inicio', component: () => import('@/views/InicioView.vue'), meta: { titulo: 'Inicio' } },
        { path: 'calendario', name: 'calendario', component: () => import('@/views/CalendarioView.vue'), meta: { titulo: 'Calendario', roles: ['vigilante'] } },
        { path: 'marcar/:turnoId', name: 'marcar', component: () => import('@/views/MarcarView.vue'), meta: { titulo: 'Marcar', roles: ['vigilante'] } },
        { path: 'ronda/:turnoId', name: 'ronda', component: () => import('@/views/RondaView.vue'), meta: { titulo: 'Ronda', roles: ['vigilante'] } },
        { path: 'incidentes/nuevo', name: 'incidente-nuevo', component: () => import('@/views/IncidenteForm.vue'), meta: { titulo: 'Incidente', roles: ['vigilante'] } },
        { path: 'cola', name: 'cola', component: () => import('@/views/ColaView.vue'), meta: { titulo: 'Pendientes', roles: ['vigilante'] } },
        { path: 'turnos', name: 'turnos', component: () => import('@/views/admin/TurnosView.vue'), meta: { titulo: 'Turnos', roles: ['administrador'] } },
        { path: 'puntos', name: 'puntos', component: () => import('@/views/admin/PuntosView.vue'), meta: { titulo: 'Puntos', roles: ['administrador'] } },
        { path: 'ventanas', name: 'ventanas', component: () => import('@/views/admin/VentanasView.vue'), meta: { titulo: 'Ventanas', roles: ['administrador'] } },
        { path: 'incidentes', name: 'incidentes', component: () => import('@/views/admin/IncidentesView.vue'), meta: { titulo: 'Incidentes', roles: ['administrador'] } },
        { path: 'alertas', name: 'alertas', component: () => import('@/views/admin/AlertasView.vue'), meta: { titulo: 'Alertas', roles: ['administrador'] } },
        { path: 'bitacora', name: 'bitacora', component: () => import('@/views/admin/BitacoraView.vue'), meta: { titulo: 'Bitácora', roles: ['administrador'] } },
        { path: 'usuarios', name: 'usuarios', component: () => import('@/views/admin/UsuariosView.vue'), meta: { titulo: 'Usuarios', roles: ['administrador'] } },
        { path: 'conjunto', name: 'conjunto', component: () => import('@/views/admin/ConjuntoView.vue'), meta: { titulo: 'Conjunto', roles: ['administrador'] } },
        { path: 'qr/:clase/:id', name: 'qr', component: () => import('@/views/QrView.vue'), meta: { titulo: 'QR', roles: ['administrador'] } },
        { path: 'perfil', name: 'perfil', component: () => import('@/views/PerfilView.vue'), meta: { titulo: 'Mi perfil' } },
      ],
    },
  ],
})

router.beforeEach(async (to) => {
  navegando.value = true
  const session = useSessionStore()
  if (!session.listo) await session.cargar()
  if (!supabaseConfigurado) return to.name === 'login' ? true : { name: 'login' }
  if (to.meta.publico) {
    if (session.session && to.name === 'login') return { name: 'inicio' }
    return true
  }
  if (!session.session) return { name: 'login', query: { redirect: to.fullPath } }
  if (to.meta.roles && !session.tiene(...to.meta.roles)) return { name: 'inicio' }
  return true
})

router.afterEach(() => {
  navegando.value = false
})

router.onError(() => {
  navegando.value = false
})

export default router
