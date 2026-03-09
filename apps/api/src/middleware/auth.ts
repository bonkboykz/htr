import type { MiddlewareHandler } from "hono";
import { AppError } from "../errors.js";

export function apiKeyAuth(): MiddlewareHandler {
  return async (c, next) => {
    const apiKey = process.env.HTR_API_KEY;

    // No key configured → skip auth (local dev mode)
    if (!apiKey) {
      return next();
    }

    const authHeader = c.req.header("Authorization");
    if (!authHeader) {
      throw new AppError(
        "UNAUTHORIZED",
        "Missing Authorization header",
        401,
        "Check your HTR_API_KEY environment variable",
      );
    }

    const [scheme, token] = authHeader.split(" ");
    if (scheme !== "Bearer" || token !== apiKey) {
      throw new AppError(
        "UNAUTHORIZED",
        "Invalid API key",
        401,
        "Check your HTR_API_KEY environment variable",
      );
    }

    return next();
  };
}
