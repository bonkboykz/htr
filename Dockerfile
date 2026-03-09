FROM node:22-slim

WORKDIR /app

RUN corepack enable

COPY package.json pnpm-workspace.yaml pnpm-lock.yaml turbo.json tsconfig.json ./
COPY packages/engine/package.json packages/engine/
COPY apps/api/package.json apps/api/

RUN pnpm install --frozen-lockfile

COPY . .

RUN pnpm build

ENV PORT=3000
ENV DATABASE_PATH=/data/htr.db

EXPOSE 3000

CMD ["node", "apps/api/dist/index.js"]
