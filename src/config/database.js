import 'dotenv/config';

import { neon, neonConfig } from '@neondatabase/serverless';
import { drizzle } from 'drizzle-orm/neon-http';

// If connecting to Neon Local proxy (e.g. inside Docker or locally), configure the HTTP endpoint
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
  try {
    const parsed = new URL(
      process.env.DATABASE_URL.replace(/^postgres(ql)?:\/\//, 'http://')
    );
    neonConfig.fetchEndpoint = `http://${parsed.host}/sql`;
    neonConfig.useSecureWebSocket = false;
    neonConfig.poolQueryViaFetch = true;
  } catch (err) {
    console.warn(
      'Could not parse DATABASE_URL for Neon Local fetchEndpoint:',
      err.message
    );
  }
}

const sql = neon(process.env.DATABASE_URL);

const db = drizzle(sql);

export { db, sql };
