# App image (no ML). Indexer/tools use target=tools.
# Default / last stage is runner — required for Render and plain `docker build`.
FROM node:22-bookworm-slim AS deps
WORKDIR /app
# Render may inject NODE_ENV=production; keep devDeps available for the Nuxt build.
ENV NODE_ENV=development
COPY package.json package-lock.json ./
# Do NOT use --omit=optional here: Nuxt needs optional platform bindings (oxc-parser).
# Skip postinstall (nuxt prepare) — project sources are not copied yet.
RUN npm ci --legacy-peer-deps --ignore-scripts

FROM node:22-bookworm-slim AS deps-tools
WORKDIR /app
ENV NODE_ENV=development
COPY package.json package-lock.json ./
RUN npm ci --legacy-peer-deps --ignore-scripts

FROM node:22-bookworm-slim AS builder
WORKDIR /app
ENV NODE_ENV=production
# Free Render builders are tight on RAM; keep Nuxt build from OOMing when possible.
ENV NODE_OPTIONS=--max-old-space-size=1536
RUN apt-get update && apt-get install -y --no-install-recommends openssl ca-certificates \
  && rm -rf /var/lib/apt/lists/*
COPY --from=deps /app/node_modules ./node_modules
COPY . .
RUN npx prisma generate
RUN npm run build
# Keep runtime lean: drop ML optional packages (used only by tools/indexer).
RUN npm uninstall --legacy-peer-deps --no-save \
    @tensorflow/tfjs-node @vladmandic/face-api sharp \
    @types/bcryptjs @types/sharp typescript \
  || true
RUN npm prune --omit=dev --legacy-peer-deps || true

FROM node:22-bookworm-slim AS tools
WORKDIR /app
ENV NODE_ENV=production
RUN apt-get update && apt-get install -y --no-install-recommends \
    openssl ca-certificates python3 make g++ \
  && rm -rf /var/lib/apt/lists/*
COPY --from=deps-tools /app/node_modules ./node_modules
COPY --from=builder /app/package.json ./package.json
COPY --from=builder /app/package-lock.json ./package-lock.json
COPY --from=builder /app/prisma ./prisma
COPY --from=builder /app/scripts ./scripts
COPY --from=builder /app/lib ./lib
COPY --from=builder /app/server/utils ./server/utils
COPY --from=builder /app/models ./models
COPY docker/entrypoint-tools.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh /app/scripts/daily-indexer-loop.sh
ENTRYPOINT ["/entrypoint.sh"]
CMD ["npx", "tsx", "scripts/index-vk.ts", "--daily"]

FROM node:22-bookworm-slim AS runner
WORKDIR /app
ENV NODE_ENV=production
ENV HOST=0.0.0.0
ENV PORT=3000
RUN apt-get update && apt-get install -y --no-install-recommends openssl ca-certificates wget \
  && rm -rf /var/lib/apt/lists/*
COPY --from=builder /app/.output ./.output
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/package.json ./package.json
COPY --from=builder /app/package-lock.json ./package-lock.json
COPY --from=builder /app/prisma ./prisma
COPY --from=builder /app/scripts/set-telegram-webhook.ts ./scripts/set-telegram-webhook.ts
COPY docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
EXPOSE 3000
ENTRYPOINT ["/entrypoint.sh"]
CMD ["node", ".output/server/index.mjs"]
