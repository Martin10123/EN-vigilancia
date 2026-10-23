import { createClient } from '@supabase/supabase-js'

const env = import.meta.env as Record<string, string | undefined>

function leer(...nombres: string[]) {
  for (const nombre of nombres) {
    const valor = env[nombre]?.trim()
    if (valor) return valor
  }
  return ''
}

const url = leer('VITE_SUPABASE_URL', 'NEXT_PUBLIC_SUPABASE_URL')
const anonKey = leer(
  'VITE_SUPABASE_ANON_KEY',
  'NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY',
  'NEXT_PUBLIC_SUPABASE_ANON_KEY',
)

export const supabaseConfigurado = url.startsWith('http') && anonKey.length > 20

export const supabase = createClient(
  supabaseConfigurado ? url : 'http://127.0.0.1:54321',
  supabaseConfigurado ? anonKey : 'anon-pendiente',
  {
    auth: {
      persistSession: true,
      autoRefreshToken: true,
      detectSessionInUrl: true,
    },
  },
)
