export class ApiRouteError extends Error {
  code: string;
  status: number;
  details?: Record<string, unknown>;

  constructor(code: string, message: string, status = 400, details?: Record<string, unknown>) {
    super(message);
    this.code = code;
    this.status = status;
    this.details = details;
  }
}

export function fromZodError(error: unknown) {
  const issues =
    typeof error === "object" &&
    error !== null &&
    "issues" in error &&
    Array.isArray((error as { issues?: unknown[] }).issues)
      ? (error as { issues: unknown[] }).issues
      : undefined;

  return new ApiRouteError("invalid_request", "Request validation failed.", 400, {
    issues,
  });
}

export function toErrorResponse(error: unknown, requestId?: string) {
  if (error instanceof ApiRouteError) {
    return Response.json(
      {
        code: error.code,
        message: error.message,
        requestId,
        details: error.details,
      },
      { status: error.status },
    );
  }

  return Response.json(
    {
      code: "internal_error",
      message: "An unexpected server error occurred.",
      requestId,
    },
    { status: 500 },
  );
}
