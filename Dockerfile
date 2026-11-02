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
# Optional offline cache:
# - _prisma_engine_cache: linux query engine from the running app (VPS)
# - _prisma_client_overlay: schema-matching client JS from `prisma generate` on a machine with CDN access
RUN if [ -f _prisma_engine_cache/prisma/client/libquery_engine-debian-openssl-3.0.x.so.node ]; then \
      mkdir -p node_modules/.prisma node_modules/@prisma/engines \
      && cp -a _prisma_engine_cache/prisma/. node_modules/.prisma/ \
      && if [ -d _prisma_engine_cache/engines ]; then cp -a _prisma_engine_cache/engines/. node_modules/@prisma/engines/; fi \
      && echo "seeded prisma engines from _prisma_engine_cache"; \
    fi
# binaries.prisma.sh is flaky from some VPS networks — retry, then keep linux engine + overlay client JS.
RUN set -e; \
    ok=0; \
    for i in 1 2 3 4 5 6; do \
      if PRISMA_ENGINES_CHECKSUM_IGNORE_MISSING=1 npx prisma generate; then ok=1; break; fi; \
      echo "prisma generate failed (attempt $i), retrying..."; \
      sleep $((i * 5)); \
    done; \
    if [ "$ok" != "1" ]; then \
      echo "WARN: prisma generate CDN failed — overlay client JS + seeded linux engine"; \
      mkdir -p node_modules/.prisma/client; \
      if [ -f _prisma_client_overlay/index.js ]; then \
        cp -a _prisma_client_overlay/. node_modules/.prisma/client/; \
      fi; \
      if [ -f _prisma_engine_cache/prisma/client/libquery_engine-debian-openssl-3.0.x.so.node ]; then \
        cp -f _prisma_engine_cache/prisma/client/libquery_engine-debian-openssl-3.0.x.so.node \
          node_modules/.prisma/client/; \
      fi; \
      test -f node_modules/.prisma/client/index.js; \
      test -f node_modules/.prisma/client/libquery_engine-debian-openssl-3.0.x.so.node; \
      grep -q 'invId' node_modules/.prisma/client/schema.prisma; \
    fi
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
# Native addons (tfjs-node, sharp) need a full toolchain; image is amd64/linux.
RUN apt-get update && apt-get install -y --no-install-recommends \
    openssl ca-certificates python3 make g++ pkg-config \
  && rm -rf /var/lib/apt/lists/*
COPY --from=deps-tools /app/node_modules ./node_modules
COPY --from=builder /app/package.json ./package.json
COPY --from=builder /app/package-lock.json ./package-lock.json
COPY --from=builder /app/prisma ./prisma
COPY --from=builder /app/scripts ./scripts
COPY --from=builder /app/lib ./lib
COPY --from=builder /app/server/utils ./server/utils
COPY --from=builder /app/models ./models
COPY --from=builder /app/_prisma_engine_cache ./_prisma_engine_cache
RUN if [ -f _prisma_engine_cache/prisma/client/libquery_engine-debian-openssl-3.0.x.so.node ]; then \
      mkdir -p node_modules/.prisma node_modules/@prisma/engines \
      && cp -a _prisma_engine_cache/prisma/. node_modules/.prisma/ \
      && if [ -d _prisma_engine_cache/engines ]; then cp -a _prisma_engine_cache/engines/. node_modules/@prisma/engines/; fi; \
    fi \
 && set -e; \
    ok=0; \
    for i in 1 2 3 4 5 6; do \
      if PRISMA_ENGINES_CHECKSUM_IGNORE_MISSING=1 npx prisma generate; then ok=1; break; fi; \
      echo "prisma generate failed (attempt $i), retrying..."; \
      sleep $((i * 5)); \
    done; \
    if [ "$ok" != "1" ]; then \
      test -f node_modules/.prisma/client/libquery_engine-debian-openssl-3.0.x.so.node; \
    fi \
  && npm rebuild sharp \
  && npm rebuild @tensorflow/tfjs-node --build-addon-from-source \
  && test -f node_modules/@tensorflow/tfjs-node/lib/napi-v8/tfjs_binding.node
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
  && rm -rf /var/lib/apt/lists/* \
  && wget -qO /tmp/docker.tgz https://download.docker.com/linux/static/stable/x86_64/docker-27.3.1.tgz \
  && tar -xzf /tmp/docker.tgz -C /tmp \
  && mv /tmp/docker/docker /usr/local/bin/docker \
  && rm -rf /tmp/docker /tmp/docker.tgz \
  && wget -qO /usr/local/bin/docker-compose \
    https://github.com/docker/compose/releases/download/v2.29.7/docker-compose-linux-x86_64 \
  && chmod +x /usr/local/bin/docker /usr/local/bin/docker-compose

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
