import { defineStore } from 'pinia'
import { computed, ref } from 'vue'
import type { Session } from '@supabase/supabase-js'
import { supabase, supabaseConfigurado } from '@/lib/supabase'

export type Perfil = {
  id: string
  nombre: string
  telefono: string | null
  activo: boolean
  conjuntoId: string | null
  aceptadoEn: string | null
}

type FilaPerfil = {
  id: string
  nombre: string
  activo: boolean
  conjunto_id: string | null
  aceptado_en: string | null
  perfil_roles: { rol_id: string }[] | null
}

export const useSessionStore = defineStore('session', () => {
  const session = ref<Session | null>(null)
  const perfil = ref<Perfil | null>(null)
  const roles = ref<string[]>([])
  const listo = ref(false)

  const nombre = computed(() => perfil.value?.nombre ?? session.value?.user.email ?? '')

  function tiene(...necesarios: string[]) {
    return necesarios.some((rol) => roles.value.includes(rol))
  }

  async function cargarPerfil() {
    const userId = session.value?.user.id
    if (!userId) {
      perfil.value = null
      roles.value = []
      return
    }
    const { data, error } = await supabase
      .from('perfiles')
      .select('id, nombre, activo, conjunto_id, aceptado_en, perfil_roles(rol_id)')
      .eq('auth_user_id', userId)
      .maybeSingle()
    if (error) throw error
    const fila = data as FilaPerfil | null
    if (!fila) {
      perfil.value = null
      roles.value = []
      return
    }
    const contacto = await supabase.from('perfiles_directorio').select('telefono').eq('id', fila.id).maybeSingle()
    perfil.value = {
      id: fila.id,
      nombre: fila.nombre,
      telefono: contacto.data?.telefono ?? null,
      activo: fila.activo,
      conjuntoId: fila.conjunto_id,
      aceptadoEn: fila.aceptado_en,
    }
    roles.value = (fila.perfil_roles ?? []).map((rol) => rol.rol_id)
  }

  async function cargar() {
    if (!supabaseConfigurado) {
      listo.value = true
      return
    }
    const { data } = await supabase.auth.getSession()
    session.value = data.session
    if (data.session) await cargarPerfil()
    listo.value = true
  }

  async function entrar(email: string, password: string) {
    const { data, error } = await supabase.auth.signInWithPassword({ email, password })
    if (error) throw error
    session.value = data.session
    await cargarPerfil()
  }

  async function salir() {
    await supabase.auth.signOut()
    session.value = null
    perfil.value = null
    roles.value = []
  }

  if (supabaseConfigurado) {
    supabase.auth.onAuthStateChange((_evento, siguiente) => {
      session.value = siguiente
      if (!siguiente) {
        perfil.value = null
        roles.value = []
        return
      }
      window.setTimeout(() => {
        void cargarPerfil()
      }, 0)
    })
  }

  return { session, perfil, roles, listo, nombre, tiene, cargar, entrar, salir, cargarPerfil }
})
