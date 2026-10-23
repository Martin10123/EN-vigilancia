<script setup lang="ts">
import { useOnline } from '@vueuse/core'
import { useQuery } from '@tanstack/vue-query'
import { Lock, Mail, ShieldAlert } from 'lucide-vue-next'
import Button from 'primevue/button'
import InputText from 'primevue/inputtext'
import Password from 'primevue/password'
import { ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { rpc } from '@/lib/api'
import { mensajeError } from '@/lib/domain'
import { supabase, supabaseConfigurado } from '@/lib/supabase'
import { useSessionStore } from '@/stores/session'

const router = useRouter()
const route = useRoute()
const session = useSessionStore()
const enLinea = useOnline()
const email = ref('')
const password = ref('')
const nombre = ref('')
const enviando = ref(false)
const error = ref('')

const hayAdmin = useQuery({
  queryKey: ['hay-admin'],
  enabled: supabaseConfigurado,
  queryFn: () => rpc<boolean>('hay_administrador'),
})

async function entrar() {
  error.value = ''
  if (!supabaseConfigurado) {
    error.value = 'Faltan VITE_SUPABASE_URL y VITE_SUPABASE_ANON_KEY en el archivo .env.'
    return
  }
  if (!email.value.includes('@') || password.value.length < 6) {
    error.value = 'Escribe un correo válido y una contraseña de al menos 6 caracteres.'
    return
  }
  enviando.value = true
  try {
    await session.entrar(email.value.trim(), password.value)
    const destino = typeof route.query.redirect === 'string' ? route.query.redirect : '/'
    await router.push(destino)
  } catch (causa) {
    error.value = mensajeError(causa)
  } finally {
    enviando.value = false
  }
}

async function crearAdmin() {
  error.value = ''
  if (nombre.value.trim().length < 3 || !email.value.includes('@') || password.value.length < 6) {
    error.value = 'Completa nombre, correo y una contraseña de al menos 6 caracteres.'
    return
  }
  enviando.value = true
  try {
    const { data, error: altaError } = await supabase.auth.signUp({
      email: email.value.trim(),
      password: password.value,
      options: { data: { nombre: nombre.value.trim() } },
    })
    if (altaError) throw altaError
    if (!data.session) {
      error.value = 'La cuenta quedó creada, pero el correo pide confirmación. En Supabase desactiva Confirm email y entra de nuevo.'
      return
    }
    session.session = data.session
    await session.cargarPerfil()
    await router.push('/')
  } catch (causa) {
    error.value = mensajeError(causa)
  } finally {
    enviando.value = false
  }
}
</script>

<template>
  <main class="relative min-h-dvh overflow-hidden bg-ink text-white">
    <div class="pointer-events-none absolute inset-0" aria-hidden="true">
      <div class="glow-drift absolute -top-24 left-[-10%] h-80 w-80 rounded-full bg-oro/30 blur-3xl" />
      <div class="glow-drift-slow absolute top-1/3 right-[-8%] h-96 w-96 rounded-full bg-amber-300/20 blur-3xl" />
      <div class="dot-grid absolute inset-0" />
    </div>
    <div class="relative grid min-h-dvh md:grid-cols-12">
      <section class="relative hidden flex-col justify-between px-10 py-12 md:col-span-6 md:flex xl:px-16">
        <div class="flex items-center gap-3">
          <span class="grid size-11 place-items-center rounded-2xl border border-white/15 bg-white/10">
            <ShieldAlert class="size-6 text-oro" aria-hidden="true" />
          </span>
          <div>
            <p class="text-sm font-semibold tracking-tight">Vigilancia</p>
            <p class="text-xs text-white/70">Conjunto residencial</p>
          </div>
        </div>
        <div class="max-w-xl">
          <p class="text-sm font-medium tracking-[0.18em] text-oro/90 uppercase">Turno y evidencia</p>
          <h1 class="mt-4 text-4xl leading-tight font-semibold tracking-tight text-balance xl:text-6xl">
            El cuaderno de la caseta, con hora y foto del servidor.
          </h1>
          <p class="mt-5 max-w-lg text-base leading-relaxed text-white/75">
            Entrada, dos rondas e incidentes. Sin recorrido de ubicación.
          </p>
        </div>
        <p class="text-xs text-white/50">Piloto interno del conjunto</p>
      </section>
      <section class="flex items-center justify-center px-4 py-8 sm:px-6 md:col-span-6">
        <form
          class="w-full max-w-md rounded-3xl border border-white/50 bg-white/85 p-5 text-slate-900 shadow-2xl shadow-slate-950/30 backdrop-blur-xl sm:p-7"
          @submit.prevent="hayAdmin.data.value ? entrar() : crearAdmin()"
        >
          <h2 class="text-2xl font-semibold tracking-tight">{{ hayAdmin.data.value === false ? 'Crear administrador' : 'Entrar' }}</h2>
          <p class="mt-1 text-sm text-slate-600">
            {{ hayAdmin.data.value === false ? 'La primera cuenta administra el conjunto. Después el registro público se cierra.' : 'Usa el correo que te asignó la administración.' }}
          </p>
          <p v-if="!supabaseConfigurado" class="mt-4 rounded-xl border border-amber-200 bg-amber-50 px-3 py-2 text-sm text-amber-950">
            Falta el archivo .env con la URL y la clave anon de Supabase.
          </p>
          <p v-if="!enLinea" class="mt-4 rounded-xl bg-slate-100 px-3 py-2 text-sm text-slate-700">Estás sin conexión. El ingreso necesita red.</p>
          <div class="mt-5 space-y-4">
            <label v-if="hayAdmin.data.value === false" class="block">
              <span class="mb-1.5 block text-sm font-medium text-slate-700">Nombre</span>
              <InputText v-model="nombre" required autocomplete="name" />
            </label>
            <label class="block">
              <span class="mb-1.5 block text-sm font-medium text-slate-700">Correo</span>
              <span class="relative block">
                <Mail class="pointer-events-none absolute top-1/2 left-3 size-4 -translate-y-1/2 text-slate-400" aria-hidden="true" />
                <InputText v-model="email" type="email" autocomplete="username" required class="pl-10" />
              </span>
            </label>
            <label class="block">
              <span class="mb-1.5 flex items-center gap-2 text-sm font-medium text-slate-700">
                <Lock class="size-4 text-slate-400" aria-hidden="true" /> Contraseña
              </span>
              <Password v-model="password" :feedback="false" toggle-mask :input-props="{ autocomplete: hayAdmin.data.value === false ? 'new-password' : 'current-password', required: true }" class="w-full" />
            </label>
          </div>
          <p v-if="error" class="mt-4 rounded-xl bg-rose-50 px-3 py-2 text-sm text-rose-800" role="alert">{{ error }}</p>
          <Button
            type="submit"
            :disabled="enviando || hayAdmin.isLoading.value"
            :pt="{ root: 'btn-shine mt-6 inline-flex min-h-12 w-full items-center justify-center rounded-xl bg-marca px-4 text-sm font-semibold text-white shadow-lg shadow-marca/30 disabled:opacity-60' }"
          >
            {{ enviando ? 'Espera…' : hayAdmin.data.value === false ? 'Crear y entrar' : 'Entrar' }}
          </Button>
        </form>
      </section>
    </div>
  </main>
</template>
