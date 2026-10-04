import 'dotenv/config';

let connectionUrl = process.env.DATABASE_URL;
if (
  connectionUrl &&
  (connectionUrl.includes('neon-local') ||
    connectionUrl.includes('localhost:5432') ||
    connectionUrl.includes('127.0.0.1:5432'))
) {
  connectionUrl = connectionUrl.replace('sslmode=require', 'sslmode=no-verify');
}

export default {
  schema: './src/models/*.js',
  out: './drizzle',
  dialect: 'postgresql',
  dbCredentials: {
    url: connectionUrl,
  },
};
