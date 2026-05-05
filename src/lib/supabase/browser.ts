import { createClient } from "@supabase/supabase-js";
import { env } from "../env";

export function createBrowserSupabaseClient() {
  return createClient(env.nextPublicSupabaseUrl(), env.nextPublicSupabaseAnonKey());
}
