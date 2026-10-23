import { supabase } from '@/lib/supabase'

export async function rpc<T>(fn: string, args?: Record<string, unknown>) {
  const { data, error } = await supabase.rpc(fn, args)
  if (error) throw error
  return data as T
}
