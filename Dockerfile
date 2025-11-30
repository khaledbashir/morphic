# Use Node.js 20
FROM node:20-alpine AS builder
WORKDIR /app

# Install pnpm (optional, but if lockfile is bun.lock, we might need bun? No, we can use npm)
# Actually, since you have bun.lock, we should install bun just to install deps, OR just delete bun.lock and use npm.
# Let's use a base image that has Bun installed but runs Node.
FROM oven/bun:1.1.27 AS base

WORKDIR /app

# Install dependencies
COPY package.json bun.lock ./
RUN bun install

# Copy source
COPY . .

# Inject Env Vars
ARG DATABASE_URL
ENV DATABASE_URL=$DATABASE_URL
ARG NEXT_PUBLIC_ENABLE_AUTH
ENV NEXT_PUBLIC_ENABLE_AUTH=$NEXT_PUBLIC_ENABLE_AUTH
ARG NEXT_PUBLIC_SUPABASE_URL
ENV NEXT_PUBLIC_SUPABASE_URL=$NEXT_PUBLIC_SUPABASE_URL
ARG NEXT_PUBLIC_SUPABASE_ANON_KEY
ENV NEXT_PUBLIC_SUPABASE_ANON_KEY=$NEXT_PUBLIC_SUPABASE_ANON_KEY

# Build (Standard Next.js build)
RUN bun next telemetry disable
RUN bun run build

# --- Runtime Stage ---
FROM node:20-alpine AS runner
WORKDIR /app

ENV NODE_ENV=production

# Copy built artifacts
COPY --from=base /app/public ./public
COPY --from=base /app/.next/standalone ./
COPY --from=base /app/.next/static ./.next/static

# Start
EXPOSE 3000
ENV PORT=3000
CMD ["node", "server.js"]
