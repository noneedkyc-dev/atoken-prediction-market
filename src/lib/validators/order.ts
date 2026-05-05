import { z } from "zod";
import { cursorSchema, limitSchema, uuidSchema } from "./common";

export const createOrderSchema = z.object({
  marketId: uuidSchema,
  outcomeId: uuidSchema,
  side: z.enum(["buy", "sell"]),
  orderType: z.enum(["limit", "market"]),
  size: z.string().min(1),
  price: z.string().min(1).optional(),
  idempotencyKey: uuidSchema,
});

export const cancelOrderSchema = z.object({
  reason: z.enum(["user_requested", "market_closed", "risk_rejected", "system_action"]).optional(),
});

export const orderListQuerySchema = z.object({
  cursor: cursorSchema,
  limit: limitSchema,
  status: z
    .enum([
      "created",
      "submission_pending",
      "submitted",
      "partially_filled",
      "filled",
      "cancel_pending",
      "cancelled",
      "failed_submission",
      "failed_cancel",
      "rejected",
      "expired",
    ])
    .optional(),
  marketId: uuidSchema.optional(),
});
