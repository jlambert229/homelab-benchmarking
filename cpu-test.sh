#!/usr/bin/env bash
set -euo pipefail

DURATION="${1:-30}"

echo "=== CPU Performance Test ==="
echo "Duration: ${DURATION}s"
echo ""

# Check if sysbench is installed
if ! command -v sysbench &> /dev/null; then
    echo "❌ sysbench not installed."
    echo ""
    echo "Install:"
    echo "  apt install sysbench      # Debian/Ubuntu"
    echo "  yum install sysbench      # RHEL/CentOS"
    echo "  brew install sysbench     # macOS"
    exit 1
fi

CORES=$(nproc)

echo "System info:"
echo "  CPU cores: $CORES"
if [[ -f /proc/cpuinfo ]]; then
    CPU_MODEL
    CPU_MODEL=$(grep "model name" /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)
    echo "  CPU model: $CPU_MODEL"
fi
echo ""

# Single-threaded performance
echo "--- Single-threaded Performance ---"
sysbench cpu --threads=1 --time="$DURATION" run | grep "events per second"

echo ""
echo "--- Multi-threaded Performance ($CORES threads) ---"
sysbench cpu --threads="$CORES" --time="$DURATION" run | grep "events per second"

# Stress test with temperature monitoring (if lm-sensors available)
echo ""
echo "--- Sustained Load Test (10 minutes) ---"
echo "This tests thermal performance and throttling"
echo ""

if command -v sensors &> /dev/null; then
    echo "Starting stress test with temperature monitoring..."
    echo "Press Ctrl+C to stop"
    echo ""

    if command -v stress-ng &> /dev/null; then
        stress-ng --cpu "$CORES" --vm 2 --vm-bytes 50% --timeout 600 --metrics &
        STRESS_PID=$!

        for i in {1..60}; do
            sleep 10
            echo "=== $((i*10))s ==="
            sensors | grep -E "Core|Package|temp" || true
        done

        kill $STRESS_PID 2>/dev/null || true
        wait $STRESS_PID 2>/dev/null || true
    else
        echo "⚠️  stress-ng not installed. Skipping stress test."
        echo "   Install: apt install stress-ng"
    fi
else
    echo "⚠️  lm-sensors not installed. Skipping temperature monitoring."
    echo "   Install: apt install lm-sensors"
fi

echo ""
echo "=== CPU Test Complete ==="
echo ""
echo "Interpreting results:"
echo "  Single-threaded:"
echo "    • 1500+ events/s: Good (modern CPU)"
echo "    • 1000-1500: Adequate"
echo "    • <1000: Slow (old CPU or VM overhead)"
echo ""
echo "  Multi-threaded scales roughly linearly with cores"
echo ""
echo "  Thermal:"
echo "    • <80°C: Good"
echo "    • 80-90°C: Warm but acceptable"
echo "    • >90°C: Throttling likely"
