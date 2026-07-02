import { Hono } from "hono";
import type { Context } from "hono";
import type { HttpBindings } from "@hono/node-server";
import { RESPONSE_ALREADY_SENT } from "@hono/node-server/utils/response";
import { StreamableHTTPServerTransport } from "@modelcontextprotocol/sdk/server/streamableHttp.js";
import { createMcpServer } from "@htr/mcp";
import type { DB } from "@htr/engine";

/**
 * Remote MCP endpoint mounted inside the API service so it shares the SAME db
 * (the Railway /data volume). Exposes streamable-http at `/mcp/:token`.
 *
 * Auth: the path `:token` (or an `Authorization: Bearer` header) must equal
 * HTR_API_KEY. When HTR_API_KEY is unset (local dev) auth is skipped.
 *
 * Stateless: a fresh McpServer + transport is created per request
 * (sessionIdGenerator: undefined) — the documented stateless pattern.
 */
export function mcpRoutes(db: DB) {
  const app = new Hono<{ Bindings: HttpBindings }>();

  const authorized = (token: string | undefined, authHeader: string | undefined): boolean => {
    const key = process.env.HTR_API_KEY;
    if (!key) return true; // local dev
    if (token === key) return true;
    if (authHeader) {
      const [scheme, value] = authHeader.split(" ");
      if (scheme === "Bearer" && value === key) return true;
    }
    return false;
  };

  const handle = async (c: Context<{ Bindings: HttpBindings }>) => {
    if (!authorized(c.req.param("token"), c.req.header("Authorization"))) {
      return c.json(
        {
          error: {
            code: "UNAUTHORIZED",
            message: "Invalid MCP token",
            suggestion: "Use https://<host>/mcp/<HTR_API_KEY> as the connector URL",
          },
        },
        401,
      );
    }

    const { incoming, outgoing } = c.env;
    let body: unknown = undefined;
    if (c.req.method === "POST") {
      body = await c.req.json().catch(() => undefined);
    }

    const server = createMcpServer(db);
    const transport = new StreamableHTTPServerTransport({
      sessionIdGenerator: undefined,
    });
    outgoing.on("close", () => {
      void transport.close();
      void server.close();
    });
    await server.connect(transport);
    await transport.handleRequest(incoming, outgoing, body);
    return RESPONSE_ALREADY_SENT;
  };

  app.post("/:token", handle);
  app.get("/:token", handle);
  app.delete("/:token", handle);

  return app;
}
