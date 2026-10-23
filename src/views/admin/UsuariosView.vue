<script setup lang="ts">
import { useQuery, useQueryClient } from '@tanstack/vue-query'
import Checkbox from 'primevue/checkbox'
import InputText from 'primevue/inputtext'
import { ref } from 'vue'
import Boton from '@/components/Boton.vue'
import Campo from '@/components/Campo.vue'
import { rpc } from '@/lib/api'
import { ROLES, mensajeError } from '@/lib/domain'
import { supabase } from '@/lib/supabase'
import { useToast } from '@/stores/toast'

type Usuario = {
  id: string
  nombre: string
  activo: boolean
  telefono: string | null
  perfil_roles: { rol_id: string }[] | null
}

const toast = useToast()
const queryClient = useQueryClient()
const email = ref('')
const password = ref('')
const nombre = ref('')
const telefono = ref('')
const roles = ref<string[]>(['vigilante'])
const guardando = ref(false)

const usuarios = useQuery({
  queryKey: ['usuarios'],
  queryFn: async () => {
    const { data, error } = await supabase.from('perfiles').select('id, nombre, activo, perfil_roles(rol_id)').order('nombre')
    if (error) throw error
    const contacto = await supabase.from('perfiles_directorio').select('id, telefono')
    if (contacto.error) throw contacto.error
    const telefonos = new Map((contacto.data ?? []).map((fila) => [fila.id, fila.telefono]))
    return (data ?? []).map((usuario) => ({ ...usuario, telefono: telefonos.get(usuario.id) ?? null })) as Usuario[]
  },
})

function marcar(id: string, activo: boolean) {
  roles.value = activo ? [...roles.value, id] : roles.value.filter((rol) => rol !== id)
}

async function crear() {
  guardando.value = true
  try {
    const { data, error } = await supabase.functions.invoke('crear-usuario', {
      body: { email: email.value, password: password.value, nombre: nombre.value, telefono: telefono.value, roles: roles.value },
    })
    if (error) throw error
    if (data?.error) throw new Error(data.error)
    email.value = ''
    password.value = ''
    nombre.value = ''
    telefono.value = ''
    toast.ok('Usuario creado. Ya puede entrar.')
    await queryClient.invalidateQueries({ queryKey: ['usuarios'] })
  } catch (error) {
    toast.error(mensajeError(error))
  } finally {
    guardando.value = false
  }
}

async function guardar(usuario: Usuario, siguientes: string[]) {
  try {
    await rpc('guardar_acceso', {
      perfil_id: usuario.id,
      roles: siguientes,
      activo: usuario.activo,
      telefono: usuario.telefono ?? '',
    })
    toast.ok('Usuario actualizado.')
    await queryClient.invalidateQueries({ queryKey: ['usuarios'] })
  } catch (error) {
    toast.error(mensajeError(error))
  }
}
</script>

<template>
  <section>
    <h1 class="text-3xl font-semibold tracking-tight">Usuarios</h1>
    <p class="mt-2 text-sm text-slate-600">El registro público está cerrado. Crea aquí a vigilantes y residentes.</p>
    <form class="mt-5 grid gap-3 rounded-3xl bg-white p-4 sm:grid-cols-2" @submit.prevent="crear">
      <Campo etiqueta="Nombre"><InputText v-model="nombre" required /></Campo>
      <Campo etiqueta="Correo"><InputText v-model="email" type="email" required /></Campo>
      <Campo etiqueta="Contraseña temporal"><InputText v-model="password" type="password" required /></Campo>
      <Campo etiqueta="Teléfono"><InputText v-model="telefono" /></Campo>
      <fieldset class="sm:col-span-2">
        <legend class="mb-2 text-sm font-medium">Roles</legend>
        <label v-for="rol in ROLES" :key="rol.id" class="mr-3 inline-flex min-h-11 items-center gap-2 text-sm">
          <Checkbox :model-value="roles.includes(rol.id)" binary @update:model-value="marcar(rol.id, Boolean($event))" />
          {{ rol.nombre }}
        </label>
      </fieldset>
      <Boton tipo="submit" :disabled="guardando">Crear usuario</Boton>
    </form>
    <ul class="mt-6 space-y-3">
      <li v-for="usuario in usuarios.data.value ?? []" :key="usuario.id" class="rounded-2xl bg-white p-4 text-sm">
        <p class="font-semibold">{{ usuario.nombre }}</p>
        <p class="text-slate-500">{{ usuario.telefono || 'Sin teléfono' }} · {{ usuario.activo ? 'Activo' : 'Inactivo' }}</p>
        <div class="mt-2 flex flex-wrap gap-2">
          <button
            v-for="rol in ROLES"
            :key="rol.id"
            type="button"
            class="min-h-9 rounded-full px-3 text-sm font-medium"
            :class="(usuario.perfil_roles ?? []).some((item) => item.rol_id === rol.id) ? 'bg-marca text-white' : 'bg-slate-100'"
            @click="guardar(usuario, (usuario.perfil_roles ?? []).some((item) => item.rol_id === rol.id) ? (usuario.perfil_roles ?? []).map((item) => item.rol_id).filter((id) => id !== rol.id) : [...(usuario.perfil_roles ?? []).map((item) => item.rol_id), rol.id])"
          >
            {{ rol.nombre }}
          </button>
          <button type="button" class="min-h-9 rounded-full bg-slate-100 px-3" @click="guardar({ ...usuario, activo: !usuario.activo }, (usuario.perfil_roles ?? []).map((item) => item.rol_id))">
            {{ usuario.activo ? 'Desactivar' : 'Activar' }}
          </button>
        </div>
      </li>
    </ul>
  </section>
</template>
