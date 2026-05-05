import { z } from "zod";
import { cursorSchema, limitSchema } from "./common";

export const paginationQuerySchema = z.object({
  cursor: cursorSchema,
  limit: limitSchema,
});

export const adminSyncJobQuerySchema = paginationQuerySchema.extend({
  status: z.string().min(1).optional(),
  jobType: z.string().min(1).optional(),
});
