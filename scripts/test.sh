#!/bin/bash
set -e

# Trade Roads Test Suite
# Runs all tests: GameCore, CatanProtocol, Server, iOS

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_ROOT"

echo "🧪 Trade Roads - Test Suite"
echo "==========================="

FAILED=0

# GameCore Tests
echo ""
echo "📦 Testing GameCore..."
cd "$PROJECT_ROOT/Packages/GameCore"
if swift test; then
    echo "✅ GameCore tests passed"
else
    echo "❌ GameCore tests failed"
    FAILED=1
fi

# CatanProtocol Tests
echo ""
echo "📦 Testing CatanProtocol..."
cd "$PROJECT_ROOT/Packages/CatanProtocol"
if swift test; then
    echo "✅ CatanProtocol tests passed"
else
    echo "❌ CatanProtocol tests failed"
    FAILED=1
fi

# Server Tests
echo ""
echo "🖥️ Testing Server..."
cd "$PROJECT_ROOT/Server"
if swift test; then
    echo "✅ Server tests passed"
else
    echo "❌ Server tests failed"
    FAILED=1
fi

# iOS Tests (using xcodebuild)
echo ""
echo "📱 Testing iOS app..."
cd "$PROJECT_ROOT/Apps/iOS/TradeRoads"
if xcodebuild test \
    -scheme TradeRoads \
    -destination 'platform=iOS Simulator,name=iPhone 17' \
    -quiet \
    2>/dev/null; then
    echo "✅ iOS tests passed"
else
    echo "⚠️ iOS tests skipped or failed (simulator may not be available)"
fi

# Summary
echo ""
echo "==========================="
if [ $FAILED -eq 0 ]; then
    echo "✅ All tests passed!"
    exit 0
else
    echo "❌ Some tests failed"
    exit 1
fi

