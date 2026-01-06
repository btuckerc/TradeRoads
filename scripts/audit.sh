#!/bin/bash
set -e

# Trade Roads Audit Script
# Fails if it finds TODO, FIXME, fatalError in production code, or obvious placeholders

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_ROOT"

echo "🔍 Trade Roads - Code Audit"
echo "==========================="

FAILED=0

# Define source directories (excluding tests)
SRC_DIRS=(
    "Packages/GameCore/Sources"
    "Packages/CatanProtocol/Sources"
    "Server/Sources"
    "Apps/iOS/TradeRoads/TradeRoads"
)

# Function to search for patterns
search_pattern() {
    local pattern=$1
    local description=$2
    local count=0
    
    for dir in "${SRC_DIRS[@]}"; do
        if [ -d "$PROJECT_ROOT/$dir" ]; then
            local matches=$(grep -r -n "$pattern" "$PROJECT_ROOT/$dir" --include="*.swift" 2>/dev/null || true)
            if [ -n "$matches" ]; then
                if [ $count -eq 0 ]; then
                    echo ""
                    echo "❌ Found $description:"
                fi
                echo "$matches" | while read line; do
                    echo "   $line"
                done
                count=$((count + $(echo "$matches" | wc -l)))
            fi
        fi
    done
    
    if [ $count -gt 0 ]; then
        FAILED=1
        return 1
    else
        echo "✅ No $description found"
        return 0
    fi
}

# Check for TODOs
search_pattern "TODO" "TODO comments" || true

# Check for FIXMEs
search_pattern "FIXME" "FIXME comments" || true

# Check for fatalError (in non-test code)
echo ""
echo "Checking for fatalError..."
for dir in "${SRC_DIRS[@]}"; do
    if [ -d "$PROJECT_ROOT/$dir" ]; then
        matches=$(grep -r -n "fatalError(" "$PROJECT_ROOT/$dir" --include="*.swift" 2>/dev/null || true)
        if [ -n "$matches" ]; then
            echo "❌ Found fatalError in production code:"
            echo "$matches" | while read line; do
                echo "   $line"
            done
            FAILED=1
        fi
    fi
done
if [ $FAILED -eq 0 ]; then
    echo "✅ No fatalError in production code"
fi

# Check for obvious placeholders
echo ""
echo "Checking for placeholder strings..."
PLACEHOLDERS=("TBD" "IMPLEMENT" "PLACEHOLDER" "stub" "NotImplemented")
for placeholder in "${PLACEHOLDERS[@]}"; do
    for dir in "${SRC_DIRS[@]}"; do
        if [ -d "$PROJECT_ROOT/$dir" ]; then
            matches=$(grep -r -n -i "$placeholder" "$PROJECT_ROOT/$dir" --include="*.swift" 2>/dev/null || true)
            if [ -n "$matches" ]; then
                echo "❌ Found '$placeholder' placeholder:"
                echo "$matches" | while read line; do
                    echo "   $line"
                done
                FAILED=1
            fi
        fi
    done
done
if [ $FAILED -eq 0 ]; then
    echo "✅ No placeholder strings found"
fi

# Check for unimplemented protocol requirements (empty methods with just 'return' or nothing)
# This is a heuristic check
echo ""
echo "Checking for suspiciously empty implementations..."
for dir in "${SRC_DIRS[@]}"; do
    if [ -d "$PROJECT_ROOT/$dir" ]; then
        # Look for methods with only a single return statement or empty bodies
        matches=$(grep -r -n "func.*{[[:space:]]*}$\|func.*{[[:space:]]*return[[:space:]]*}$" "$PROJECT_ROOT/$dir" --include="*.swift" 2>/dev/null || true)
        if [ -n "$matches" ]; then
            echo "⚠️ Found potentially empty implementations (review manually):"
            echo "$matches" | head -10 | while read line; do
                echo "   $line"
            done
        fi
    fi
done

# Summary
echo ""
echo "==========================="
if [ $FAILED -eq 0 ]; then
    echo "✅ Audit passed!"
    exit 0
else
    echo "❌ Audit failed - please fix the issues above"
    exit 1
fi

