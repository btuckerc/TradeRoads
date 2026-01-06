#!/bin/bash
set -e

# Trade Roads Development Server Script
# Boots Postgres, runs migrations, and starts the server

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_ROOT"

echo "🎮 Trade Roads - Development Server"
echo "===================================="

# Check for Docker
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is required but not installed."
    echo "   Please install Docker Desktop from https://docker.com"
    exit 1
fi

# Start Postgres
echo "🐘 Starting PostgreSQL..."
docker compose up -d postgres

# Wait for Postgres to be ready
echo "⏳ Waiting for PostgreSQL to be ready..."
for i in {1..30}; do
    if docker compose exec -T postgres pg_isready -U traderoads -d traderoads &> /dev/null; then
        echo "✅ PostgreSQL is ready!"
        break
    fi
    if [ $i -eq 30 ]; then
        echo "❌ PostgreSQL failed to start within 30 seconds"
        exit 1
    fi
    sleep 1
done

# Set environment variables
export DATABASE_URL="postgres://traderoads:traderoads_dev@localhost/traderoads"
export AUTH_SECRET="dev-secret-key-do-not-use-in-production"

# Build and run the server
echo "🔨 Building server..."
cd "$PROJECT_ROOT/Server"
swift build

echo "🚀 Starting server..."
echo "   Server will be available at: http://localhost:8080"
echo "   WebSocket endpoint: ws://localhost:8080/ws"
echo "   Health check: http://localhost:8080/health"
echo ""
echo "Press Ctrl+C to stop the server"
echo ""

swift run TradeRoadsServer

