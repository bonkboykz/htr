import { createServer } from "node:http";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { StreamableHTTPServerTransport } from "@modelcontextprotocol/sdk/server/streamableHttp.js";
import { createAndMigrateDb, seedMeals, seedTraining } from "@htr/engine";
import { createMcpServer } from "./server.js";

const dbPath = process.env.DATABASE_PATH || "htr.db";

const db = createAndMigrateDb(dbPath);
seedMeals(db);
seedTraining(db);

const server = createMcpServer(db);

async function main() {
  if (process.env.MCP_TRANSPORT === "http") {
    const port = parseInt(process.env.PORT || "3001", 10);

    // Stateless streamable-http: one transport, no session tracking.
    const transport = new StreamableHTTPServerTransport({
      sessionIdGenerator: undefined,
    });
    await server.connect(transport);

    const httpServer = createServer((req, res) => {
      if (req.url !== "/mcp") {
        res.writeHead(404).end();
        return;
      }
      const chunks: Buffer[] = [];
      req.on("data", (c) => chunks.push(c as Buffer));
      req.on("end", () => {
        let body: unknown;
        if (chunks.length > 0) {
          try {
            body = JSON.parse(Buffer.concat(chunks).toString("utf8"));
          } catch {
            body = undefined;
          }
        }
        void transport.handleRequest(req, res, body);
      });
    });

    httpServer.listen(port, () => {
      console.error(`HTR MCP (streamable-http) listening on :${port}/mcp`);
    });

    const shutdown = () => httpServer.close(() => process.exit(0));
    process.on("SIGTERM", shutdown);
    process.on("SIGINT", shutdown);
  } else {
    const transport = new StdioServerTransport();
    await server.connect(transport);
    console.error("HTR MCP (stdio) ready");
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
