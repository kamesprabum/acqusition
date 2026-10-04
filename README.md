# Acquisition API - Docker & Neon Database Architecture

A production-ready Node.js & Express REST API dockerized with dual-environment support for **Neon Database**:

- **Local Development**: Uses **Neon Local** proxy with automatic ephemeral branch creation and teardown.
- **Production**: Connects directly to serverless **Neon Cloud Postgres** without proxies.

---

## Architecture Overview

```
                      ┌──────────────────────────────────────────────┐
                      │              Docker Compose                  │
                      │                                              │
                      │  ┌────────────────┐   postgres://...         │
                      │  │   App (Dev)    │ ─────────────────┐       │
                      │  └────────────────┘                  ▼       │
                      │                           ┌────────────────┐ │
                      │                           │   Neon Local   │ │
                      │                           │     Proxy      │ │
                      │                           └───────┬────────┘ │
                      └───────────────────────────────────┼──────────┘
DEVELOPMENT                                               │ (Cloud API / Wire)
                                                          ▼
                                            ┌───────────────────────────┐
                                            │ Neon Ephemeral Branch     │
                                            │ (Cloned from parent/main) │
                                            └───────────────────────────┘
─────────────────────────────────────────────────────────────────────────
PRODUCTION
                      ┌──────────────────────────────────────────────┐
                      │              Docker Host / VM                │
                      │                                              │
                      │  ┌────────────────┐                          │
                      │  │   App (Prod)   │                          │
                      │  └───────┬────────┘                          │
                      └──────────┼───────────────────────────────────┘
                                 │ SSL (postgres://...neon.tech/...)
                                 ▼
                      ┌───────────────────────────┐
                      │    Neon Cloud Database    │
                      │   (Serverless Postgres)   │
                      └───────────────────────────┘
```

---

## Environment Matrix

| Feature              | Local Development (`dev`)                                                       | Production (`prod`)               |
| :------------------- | :------------------------------------------------------------------------------ | :-------------------------------- |
| **Compose File**     | `docker-compose.dev.yml` (or `docker-compose.yml`)                              | `docker-compose.prod.yml`         |
| **Env File**         | `.env.development`                                                              | `.env.production`                 |
| **Database Host**    | `neon-local:5432` (Docker network) or `localhost:5432` (host)                   | `*.aws.neon.tech` (Neon Cloud)    |
| **Neon Proxy**       | Running via `neondatabase/neon_local:latest`                                    | **None** (direct SSL connection)  |
| **Branch Lifecycle** | **Ephemeral**: Automatically created on startup, deleted on container stop      | **Permanent**: Production branch  |
| **Driver Mode**      | HTTP proxy endpoint (`neonConfig.fetchEndpoint = 'http://neon-local:5432/sql'`) | Serverless Neon over HTTPS/SSL    |
| **Container User**   | `node` (unprivileged)                                                           | `node` (unprivileged)             |
| **Live Reload**      | Enabled (`node --watch` + `./src` bind mount)                                   | Disabled (`npm start` standalone) |

---

## 1. Local Development with Neon Local

Neon Local creates a proxy inside the Docker Compose network that connects your local container to an **ephemeral branch** in your Neon project. Every time you spin up the container, you get a clean database branch cloned from your parent branch (e.g. `main`), and it is automatically deleted when you shut down the container.

### Step 1: Prerequisites

- [Docker & Docker Compose](https://docs.docker.com/get-docker/) installed.
- A Neon account at [neon.tech](https://neon.tech).
- Your **Neon API Key** (Account Settings → API Keys).
- Your **Neon Project ID** (Project Settings → General).

### Step 2: Configure `.env.development`

Create or update `.env.development`:

```ini
PORT=3000
NODE_ENV=development
LOG_LEVEL=debug

# Neon Cloud Credentials for Neon Local Proxy
NEON_API_KEY=your_neon_api_key_here
NEON_PROJECT_ID=your_neon_project_id_here

# Parent branch from which ephemeral branches will be created
PARENT_BRANCH_ID=main

# Database URL pointing to the neon-local service within the Docker network
# Default credentials for Neon Local proxy: neon:npg
DATABASE_URL=postgres://neon:npg@neon-local:5432/acqusition?sslmode=require

# Arcjet Key (Optional for local development)
ARCJET_KEY=
```

### Step 3: Start the Development Environment

Run using npm script or Docker Compose directly:

```bash
# Using npm
npm run docker:dev

# Or using docker compose directly
docker compose -f docker-compose.dev.yml up --build
# (or just `docker compose up --build`)
```

When started:

1. `neon-local` contacts the Neon API and creates a new ephemeral branch off `PARENT_BRANCH_ID`.
2. `neon-local` exposes port `5432` on the Docker bridge network `acqusition-net` and to `localhost:5432`.
3. `app` waits for `neon-local` to be healthy, connects using `DATABASE_URL`, and starts in watch mode.
4. Any code changes made to `src/` on your host machine instantly hot-reload inside the container.

### Step 4: Run Database Migrations

To push Drizzle migrations to the ephemeral branch:

```bash
# Execute migration inside the running app container
docker compose -f docker-compose.dev.yml exec app npm run db:migrate

# Or run from your host machine (points to localhost:5432)
DATABASE_URL=postgres://neon:npg@localhost:5432/acqusition?sslmode=require npm run db:migrate
```

### Step 5: Stop the Development Environment & Teardown

```bash
# Using npm
npm run docker:dev:down

# Or using docker compose
docker compose -f docker-compose.dev.yml down
```

> **Note**: Because `DELETE_BRANCH=true` is set, Neon Local automatically sends an API request to Neon to cleanly delete the ephemeral branch upon shutdown!

---

## 2. Production Deployment with Neon Cloud

In production, no proxy is used. Your application connects securely and directly to your Neon Cloud Serverless Postgres endpoint over SSL.

### Step 1: Configure `.env.production`

Create `.env.production` on your deployment server (or inject these environment variables in your CI/CD / container orchestrator):

```ini
PORT=3000
NODE_ENV=production
LOG_LEVEL=info

# Production Neon Cloud Database URL from the Neon Console
DATABASE_URL=postgres://<user>:<password>@<endpoint-id>.<region>.aws.neon.tech/<dbname>?sslmode=require

# Arcjet Security Key
ARCJET_KEY=ajkey_prod_your_real_key_here
```

> **Security Note**: Never commit `.env.production` into version control. It is already added to `.dockerignore` and `.gitignore`.

### Step 2: Run Production Migrations

Before or during deployment, apply migrations against the production database:

```bash
DATABASE_URL="postgres://<user>:<password>@<endpoint-id>.<region>.aws.neon.tech/<dbname>?sslmode=require" npm run db:migrate
```

### Step 3: Start the Production Container

```bash
# Using npm
npm run docker:prod

# Or using docker compose directly
docker compose -f docker-compose.prod.yml up --build -d
```

### Step 4: Inspect Container & Logs

```bash
# Check status and healthcheck
docker compose -f docker-compose.prod.yml ps

# View live structured logs
docker compose -f docker-compose.prod.yml logs -f app
```

### Step 5: Stop Production

```bash
npm run docker:prod:down
# or
docker compose -f docker-compose.prod.yml down
```

---

## 3. How Environment Variables (`DATABASE_URL`) Switch

The application code in `src/config/database.js` dynamically adapts to either environment:

```javascript
// src/config/database.js
import 'dotenv/config';
import { neon, neonConfig } from '@neondatabase/serverless';
import { drizzle } from 'drizzle-orm/neon-http';

// If connecting through Neon Local proxy in development, route HTTP calls to the proxy
if (process.env.NEON_FETCH_ENDPOINT) {
  neonConfig.fetchEndpoint = process.env.NEON_FETCH_ENDPOINT;
  neonConfig.useSecureWebSocket = false;
  neonConfig.poolQueryViaFetch = true;
} else if (
  process.env.DATABASE_URL &&
  (process.env.DATABASE_URL.includes('neon-local') ||
    process.env.DATABASE_URL.includes('localhost:5432') ||
    process.env.DATABASE_URL.includes('127.0.0.1:5432'))
) {
  const parsed = new URL(
    process.env.DATABASE_URL.replace(/^postgres(ql)?:\/\//, 'http://')
  );
  neonConfig.fetchEndpoint = `http://${parsed.host}/sql`;
  neonConfig.useSecureWebSocket = false;
  neonConfig.poolQueryViaFetch = true;
}

const sql = neon(process.env.DATABASE_URL);
const db = drizzle(sql);

export { db, sql };
```

- **In Development**:
  `DATABASE_URL=postgres://neon:npg@neon-local:5432/acqusition?sslmode=require`
  The host `neon-local` resolves to the local proxy container. The proxy translates queries to the cloud ephemeral branch.
- **In Production**:
  `DATABASE_URL=postgres://user:pass@ep-cool-fog-123456.us-east-2.aws.neon.tech/acqusition?sslmode=require`
  The host is an external Neon cloud endpoint. `neonConfig` stays untouched, connecting over high-performance HTTPS serverless transport.

---

## 4. API Endpoints for Verification

Once running, verify endpoints via curl or the `api.http` scratchpad:

```bash
# Health Check
curl http://localhost:3000/health
# Response: {"status":"ok","timestamp":"...","uptime":...}

# Healthz Check
curl http://localhost:3000/healthz
# Response: {"message":"Acquisition API is healthy"}

# User Registration
curl -X POST http://localhost:3000/api/auth/sign-up \
  -H "Content-Type: application/json" \
  -d '{"name":"Dev User","email":"dev@example.com","password":"securePassword123"}'
```
