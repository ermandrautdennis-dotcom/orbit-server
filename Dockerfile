# Multi-stage build. The runtime image carries production dependencies and the
# application only — no toolchain, no dev dependencies, no .git.
FROM node:22-bookworm-slim AS deps
WORKDIR /app
# Build tooling is present only in this stage, for the optional native argon2
# module. If it fails to build, the application falls back to scrypt.
RUN apt-get update && apt-get install -y --no-install-recommends python3 make g++ \
    && rm -rf /var/lib/apt/lists/*
COPY package.json package-lock.json* ./
RUN npm ci --omit=dev --no-audit --no-fund || npm install --omit=dev --no-audit --no-fund

FROM node:22-bookworm-slim AS runtime
ENV NODE_ENV=production \
    NPM_CONFIG_UPDATE_NOTIFIER=false
WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates wget \
    && rm -rf /var/lib/apt/lists/*

COPY --from=deps /app/node_modules ./node_modules
COPY package.json ./
COPY backend ./backend
COPY bot ./bot
COPY lua ./lua
COPY database ./database
COPY scripts ./scripts

# Run unprivileged. The image ships read-only application files; nothing is
# written to disk at runtime.
RUN chown -R node:node /app
USER node

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD wget -qO- http://127.0.0.1:${PORT:-3000}/health >/dev/null || exit 1

# Migrations run at boot so a deploy is a single step. They are idempotent and
# recorded with a checksum, so repeated starts and multiple replicas are safe.
CMD ["sh", "-c", "node database/migrate.js up && node backend/src/server.js"]
