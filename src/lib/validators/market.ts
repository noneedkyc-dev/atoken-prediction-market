import { z } from "zod";
import { cursorSchema, limitSchema } from "./common";

export const marketListQuerySchema = z.object({
  cursor: cursorSchema,
  limit: limitSchema,
  status: z.enum(["open", "paused", "closed", "settled"]).optional(),
  category: z.string().min(1).optional(),
  search: z.string().min(1).optional(),
  featuredOnly: z.coerce.boolean().optional(),
  sort: z.enum(["curated_rank", "volume_24h", "close_time"]).optional(),
});
