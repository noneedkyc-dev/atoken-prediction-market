function required(name: string): string {
  const value = process.env[name];
  if (!value) {
    throw new Error(`Missing required environment variable: ${name}`);
  }
  return value;
}

function optionalNumber(name: string, fallback: number): number {
  const raw = process.env[name];
  if (!raw) {
    return fallback;
  }
  const parsed = Number(raw);
  if (Number.isNaN(parsed)) {
    throw new Error(`Invalid numeric environment variable: ${name}`);
  }
  return parsed;
}

export const env = {
  nextPublicSupabaseUrl: () => required("NEXT_PUBLIC_SUPABASE_URL"),
  nextPublicSupabaseAnonKey: () => required("NEXT_PUBLIC_SUPABASE_ANON_KEY"),
  supabaseServiceRoleKey: () => required("SUPABASE_SERVICE_ROLE_KEY"),
  polymarketApiBaseUrl: () => required("POLYMARKET_API_BASE_URL"),
  polymarketSignerPrivateKey: () => required("POLYMARKET_SIGNER_PRIVATE_KEY"),
  atokenOrderMaxNotional: () => optionalNumber("ATOKEN_ORDER_MAX_NOTIONAL", 1000),
};
