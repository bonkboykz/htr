import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import type { DB } from "@htr/engine";
import { tools } from "./tools.js";

/**
 * Build an McpServer with every HTR tool registered against the given db.
 * Each handler's plain-object result is wrapped into MCP text content.
 */
export function createMcpServer(db: DB): McpServer {
  const server = new McpServer({ name: "htr", version: "0.1.0" });

  for (const tool of tools) {
    server.registerTool(
      tool.name,
      {
        description: tool.description,
        inputSchema: tool.schema.shape,
      },
      async (args: unknown) => {
        try {
          const result = tool.handler(db, args);
          return {
            content: [{ type: "text", text: JSON.stringify(result) }],
          };
        } catch (err) {
          const message = err instanceof Error ? err.message : String(err);
          return {
            isError: true,
            content: [
              {
                type: "text",
                text: JSON.stringify({ error: { message } }),
              },
            ],
          };
        }
      },
    );
  }

  return server;
}
