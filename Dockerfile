# Multi-stage Dockerfile for development and production

# -------------------------------------------------------------
# Base stage: Node.js 22 LTS Alpine base
# -------------------------------------------------------------
FROM node:22-alpine AS base
WORKDIR /app

# -------------------------------------------------------------
# Dependencies stage: Install all dependencies (including dev)
# -------------------------------------------------------------
FROM base AS dev-deps
RUN apk add --no-cache python3 make g++
COPY package.json package-lock.json ./
RUN npm ci

# -------------------------------------------------------------
# Development stage: Live watch mode with full dev tooling
# -------------------------------------------------------------
FROM base AS development
ENV NODE_ENV=development
ENV PORT=3000

COPY --from=dev-deps /app/node_modules ./node_modules
COPY . .

# Ensure logs directory exists with appropriate permissions
RUN mkdir -p /app/logs && chown -R node:node /app/logs

USER node
EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD node -e "fetch('http://localhost:' + (process.env.PORT || 3000) + '/health').then(r => process.exit(r.ok ? 0 : 1)).catch(() => process.exit(1))"

CMD ["npm", "run", "dev"]

# -------------------------------------------------------------
# Production dependencies stage: Only production packages
# -------------------------------------------------------------
FROM base AS prod-deps
RUN apk add --no-cache python3 make g++
COPY package.json package-lock.json ./
RUN npm ci --omit=dev

# -------------------------------------------------------------
# Production stage: Minimal, secure runtime container
# -------------------------------------------------------------
FROM base AS production
ENV NODE_ENV=production
ENV PORT=3000

# Create application & logs directory with non-root user permissions
RUN mkdir -p /app/logs && chown -R node:node /app

USER node

# Copy production node_modules and application code
COPY --chown=node:node --from=prod-deps /app/node_modules ./node_modules
COPY --chown=node:node package.json ./
COPY --chown=node:node src ./src
COPY --chown=node:node drizzle ./drizzle
COPY --chown=node:node drizzle.config.js ./

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD node -e "fetch('http://localhost:' + (process.env.PORT || 3000) + '/health').then(r => process.exit(r.ok ? 0 : 1)).catch(() => process.exit(1))"

CMD ["npm", "start"]
