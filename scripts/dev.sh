#!/bin/bash
set -e

# Development startup script for Acquisition App with Neon Local
# This script starts the application in development mode with Neon Local

echo "🚀 Starting Acquisition App in Development Mode"
echo "================================================"

# Check if .env.development exists
if [ ! -f .env.development ]; then
    echo "❌ Error: .env.development file not found!"
    echo "   Please copy .env.development from the template and update with your Neon credentials."
    exit 1
fi

# Check if Docker is running
if ! docker info >/dev/null 2>&1; then
    echo "❌ Error: Docker is not running!"
    echo "   Please start Docker Desktop and try again."
    exit 1
fi

# Create .neon_local directory if it doesn't exist
mkdir -p .neon_local

# Add .neon_local to .gitignore if not already present
if ! grep -q "\.neon_local" .gitignore 2>/dev/null; then
    echo ".neon_local/" >> .gitignore
    echo "✅ Added .neon_local/ to .gitignore"
fi

echo "📦 Building and starting development containers..."
echo "   - Neon Local proxy routing to configured Neon branch"
echo "   - Application running with live code reloading"
echo ""

# Start services in detached mode
docker compose -f docker-compose.dev.yml up --build -d

# Wait for Neon Local database service to be ready
echo "⏳ Waiting for database to be ready..."
until docker compose -f docker-compose.dev.yml exec -T neon-local pg_isready -h localhost -p 5432 >/dev/null 2>&1; do
    sleep 1
done
echo "✅ Database is accepting connections."

# Run Drizzle migrations inside the app container
echo "📜 Applying latest schema with Drizzle..."
docker compose -f docker-compose.dev.yml exec -T app npm run db:migrate

# Read port from .env.development or default to 3000
APP_PORT=$(grep -E '^PORT=' .env.development | cut -d '=' -f2 | tr -d ' "\r' || true)
APP_PORT=${APP_PORT:-3000}

echo ""
echo "🎉 Development environment started successfully!"
echo "   Application: http://localhost:${APP_PORT}"
echo "   Database:    postgres://neon:npg@localhost:5432/acqusition"
echo ""
echo "Streaming logs (press Ctrl+C to stop)..."

trap 'echo ""; echo "🛑 Stopping development environment..."; docker compose -f docker-compose.dev.yml down; exit 0' INT TERM

docker compose -f docker-compose.dev.yml logs -f