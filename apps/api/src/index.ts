import { serve } from "@hono/node-server";
import { createAndMigrateDb, seedMeals } from "@htr/engine";
import { createApp } from "./app.js";

const port = parseInt(process.env.PORT || "3000", 10);
const dbPath = process.env.DATABASE_PATH || "htr.db";

const db = createAndMigrateDb(dbPath);
console.log("Migrations completed.");

seedMeals(db);
console.log("System meals seeded.");

const app = createApp(db);

const server = serve({ fetch: app.fetch, port }, (info) => {
  console.log(`HTR API running on http://localhost:${info.port}`);
});

function shutdown() {
  console.log("Shutting down gracefully...");
  server.close(() => {
    console.log("Server closed.");
    process.exit(0);
  });
}

process.on("SIGTERM", shutdown);
process.on("SIGINT", shutdown);
