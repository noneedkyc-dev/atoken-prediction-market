import type { AppRole } from "../contracts/api";
import { headers } from "next/headers";

export interface RequestContext {
  requestId: string;
  userId?: string;
  role?: AppRole;
}

export async function getRequestContext(): Promise<RequestContext> {
  const headerStore = await headers();
  const requestId = headerStore.get("x-request-id") ?? crypto.randomUUID();
  const roleHeader = headerStore.get("x-atoken-role");
  const role =
    roleHeader === "user" || roleHeader === "operator" || roleHeader === "admin"
      ? roleHeader
      : undefined;

  return {
    requestId,
    userId: headerStore.get("x-atoken-user-id") ?? undefined,
    role,
  };
}
