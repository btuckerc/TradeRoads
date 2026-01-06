# Running Trade Roads

## Prerequisites

- **macOS 14+** (for iOS development)
- **Xcode 16+** (Swift 6.0)
- **Docker** (for PostgreSQL)

## Quick Start

### 1. Start the Development Server

```bash
./scripts/dev.sh
```

This will:
1. Start PostgreSQL in Docker
2. Wait for the database to be ready
3. Build and run the Vapor server
4. Server available at `http://localhost:8080`

### 2. Run the iOS App

1. Open `Apps/iOS/TradeRoads/TradeRoads.xcodeproj` in Xcode
2. Select a simulator (iPhone 17 or similar)
3. Build and Run (⌘R)

The app will connect to `ws://localhost:8080/ws` by default.

## Manual Setup

### PostgreSQL

Start just the database:

```bash
docker compose up -d postgres
```

Verify it's running:

```bash
docker compose ps
docker compose logs postgres
```

Connection details:
- Host: `localhost`
- Port: `5432`
- Database: `traderoads`
- User: `traderoads`
- Password: `traderoads_dev`

### Server

Build the server:

```bash
cd Server
swift build
```

Run with custom database URL:

```bash
DATABASE_URL="postgres://user:pass@host/db" swift run TradeRoadsServer
```

Environment variables:
- `DATABASE_URL` - PostgreSQL connection string
- `AUTH_SECRET` - HMAC signing key for session tokens

### iOS App

Build from command line:

```bash
cd Apps/iOS/TradeRoads
xcodebuild -scheme TradeRoads -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Override server URL:

```bash
SERVER_URL="ws://192.168.1.100:8080/ws" # Set in scheme environment
```

## Testing

Run all tests:

```bash
./scripts/test.sh
```

Run individual test suites:

```bash
# GameCore
cd Packages/GameCore && swift test

# CatanProtocol
cd Packages/CatanProtocol && swift test

# Server
cd Server && swift test

# iOS
cd Apps/iOS/TradeRoads
xcodebuild test -scheme TradeRoads -destination 'platform=iOS Simulator,name=iPhone 17'
```

## Endpoints

### HTTP

- `GET /health` - Health check (returns `{"status": "ok"}`)
- `GET /api/version` - Protocol version info
- `POST /api/auth/register` - Create account
- `POST /api/auth/login` - Get session token
- `POST /api/auth/refresh` - Refresh session

### WebSocket

- `ws://localhost:8080/ws` - Game WebSocket endpoint

## Troubleshooting

### Database Connection Failed

```bash
# Check if Postgres is running
docker compose ps

# Restart Postgres
docker compose restart postgres

# Check logs
docker compose logs postgres
```

### Server Won't Start

```bash
# Check for port conflicts
lsof -i :8080

# Rebuild clean
cd Server
rm -rf .build
swift build
```

### iOS App Can't Connect

1. Ensure server is running
2. Check firewall settings
3. Verify WebSocket URL in app
4. For device testing, use your Mac's local IP instead of `localhost`

### Tests Failing

```bash
# Clean build
swift package clean

# Update dependencies
swift package update

# Run with verbose output
swift test --verbose
```

## Production Deployment

For production:

1. Use a real PostgreSQL instance
2. Set a strong `AUTH_SECRET` environment variable
3. Configure TLS/SSL for WebSocket connections
4. Set up proper logging and monitoring
5. Consider horizontal scaling for game servers

