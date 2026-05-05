import { z } from "zod";

export const cursorSchema = z.string().min(1).optional();
export const limitSchema = z.coerce.number().int().min(1).max(100).optional();
export const uuidSchema = z.string().uuid();

export function parseSearchParams(searchParams: URLSearchParams): Record<string, string> {
  return Object.fromEntries(searchParams.entries());
}
