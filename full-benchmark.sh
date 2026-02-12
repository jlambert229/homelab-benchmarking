#!/usr/bin/env bash
set -euo pipefail

OUTPUT_DIR="${OUTPUT_DIR:-./results}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUTPUT_FILE="$OUTPUT_DIR/benchmark-${TIMESTAMP}.txt"

# Configuration
NAS_IP="${NAS_IP:-192.168.1.10}"
NFS_MOUNT="${NFS_MOUNT:-/mnt/nfs-test}"

mkdir -p "$OUTPUT_DIR"

echo "=== Homelab Full Benchmark ===" | tee "$OUTPUT_FILE"
echo "Date: $(date)" | tee -a "$OUTPUT_FILE"
echo "Hostname: $(hostname)" | tee -a "$OUTPUT_FILE"
echo "" | tee -a "$OUTPUT_FILE"

# System info
echo "--- System Information ---" | tee -a "$OUTPUT_FILE"
if [[ -f /proc/cpuinfo ]]; then
    CPU_MODEL
    CPU_MODEL=$(grep "model name" /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)
    CPU_CORES
    CPU_CORES=$(nproc)
    echo "CPU: $CPU_MODEL ($CPU_CORES cores)" | tee -a "$OUTPUT_FILE"
fi
if [[ -f /proc/meminfo ]]; then
    MEM_TOTAL
    MEM_TOTAL=$(grep MemTotal /proc/meminfo | awk '{printf "%.1f GB", $2/1024/1024}')
    echo "RAM: $MEM_TOTAL" | tee -a "$OUTPUT_FILE"
fi
echo "" | tee -a "$OUTPUT_FILE"

# Network test
echo "--- Network: ${HOSTNAME} → $NAS_IP ---" | tee -a "$OUTPUT_FILE"
if command -v iperf3 &> /dev/null; then
    echo "Starting iperf3 test (requires server running on $NAS_IP)..." | tee -a "$OUTPUT_FILE"
    iperf3 -c "$NAS_IP" -t 10 2>&1 | grep sender | tee -a "$OUTPUT_FILE" || echo "iperf3 test failed" | tee -a "$OUTPUT_FILE"
else
    echo "⚠️  iperf3 not installed. Skipping network test." | tee -a "$OUTPUT_FILE"
fi
echo "" | tee -a "$OUTPUT_FILE"

# NFS test (if mount exists)
if [[ -d "$NFS_MOUNT" ]]; then
    echo "--- NFS Performance ($NFS_MOUNT) ---" | tee -a "$OUTPUT_FILE"

    TEST_FILE="$NFS_MOUNT/benchmark-$$.img"

    echo "Sequential write:" | tee -a "$OUTPUT_FILE"
    dd if=/dev/zero of="$TEST_FILE" bs=1M count=1024 conv=fdatasync 2>&1 | grep copied | tee -a "$OUTPUT_FILE"

    sync
    echo 3 | sudo tee /proc/sys/vm/drop_caches > /dev/null 2>&1 || true

    echo "Sequential read:" | tee -a "$OUTPUT_FILE"
    dd if="$TEST_FILE" of=/dev/null bs=1M 2>&1 | grep copied | tee -a "$OUTPUT_FILE"

    rm -f "$TEST_FILE"
else
    echo "⚠️  NFS mount $NFS_MOUNT not found. Skipping NFS tests." | tee -a "$OUTPUT_FILE"
fi
echo "" | tee -a "$OUTPUT_FILE"

# CPU test
echo "--- CPU Performance ---" | tee -a "$OUTPUT_FILE"
if command -v sysbench &> /dev/null; then
    echo "Single-threaded:" | tee -a "$OUTPUT_FILE"
    sysbench cpu --threads=1 --time=10 run 2>&1 | grep "events per second" | tee -a "$OUTPUT_FILE"

    echo "Multi-threaded:" | tee -a "$OUTPUT_FILE"
    sysbench cpu --threads="$(nproc)" --time=10 run 2>&1 | grep "events per second" | tee -a "$OUTPUT_FILE"
else
    echo "⚠️  sysbench not installed. Skipping CPU tests." | tee -a "$OUTPUT_FILE"
fi
echo "" | tee -a "$OUTPUT_FILE"

# Summary
echo "=== Benchmark Complete ===" | tee -a "$OUTPUT_FILE"
echo "" | tee -a "$OUTPUT_FILE"
echo "Report saved: $OUTPUT_FILE" | tee -a "$OUTPUT_FILE"
echo "" | tee -a "$OUTPUT_FILE"
echo "Compare with previous results:"
echo "  diff $OUTPUT_FILE results/benchmark-<previous-date>.txt"
echo ""
echo "Run quarterly to establish baselines and detect degradation."
