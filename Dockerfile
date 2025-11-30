# Base image - Using 1.1.27 for stability
FROM oven/bun:1.1.27 AS builder

WORKDIR /app

# Install dependencies
COPY package.json bun.lock ./
RUN bun install

# Copy source code
COPY . .

# --- FIX: Inject Easypanel Env Vars into Build ---
ARG DATABASE_URL
ENV DATABASE_URL=$DATABASE_URL

ARG NEXT_PUBLIC_ENABLE_AUTH
ENV NEXT_PUBLIC_ENABLE_AUTH=$NEXT_PUBLIC_ENABLE_AUTH

ARG NEXT_PUBLIC_SUPABASE_URL
ENV NEXT_PUBLIC_SUPABASE_URL=$NEXT_PUBLIC_SUPABASE_URL

ARG NEXT_PUBLIC_SUPABASE_ANON_KEY
ENV NEXT_PUBLIC_SUPABASE_ANON_KEY=$NEXT_PUBLIC_SUPABASE_ANON_KEY
# -------------------------------------------------

RUN bun next telemetry disable
RUN bun run build

# Runtime stage
FROM oven/bun:1.1.27 AS runner
WORKDIR /app

# Copy only necessary files from builder
COPY --from=builder /app/.next ./.next
COPY --from=builder /app/public ./public
COPY --from=builder /app/package.json ./package.json
COPY --from=builder /app/bun.lock ./bun.lock
COPY --from=builder /app/node_modules ./node_modules

# Copy migration files and scripts
COPY --from=builder /app/drizzle ./drizzle
COPY --from=builder /app/lib/db ./lib/db
COPY --from=builder /app/drizzle.config.ts ./drizzle.config.ts

# Create entrypoint script for database migration
RUN echo '#!/bin/sh\n\
set -e\n\
echo "Running database migrations..."\n\
bun run migrate\n\
echo "Migrations completed. Starting server..."\n\
exec "$@"\n' > /app/docker-entrypoint.sh && chmod +x /app/docker-entrypoint.sh

# Start production server with migration
ENTRYPOINT ["/app/docker-entrypoint.sh"]
CMD ["bun", "start", "-H", "0.0.0.0"]
