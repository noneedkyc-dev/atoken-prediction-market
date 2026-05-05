import { createClient } from "@supabase/supabase-js";
import { env } from "../env";

export function createServerSupabaseAnonClient() {
  return createClient(env.nextPublicSupabaseUrl(), env.nextPublicSupabaseAnonKey(), {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
    },
  });
}

export function createServerSupabaseServiceClient() {
  return createClient(env.nextPublicSupabaseUrl(), env.supabaseServiceRoleKey(), {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
    },
  });
}
