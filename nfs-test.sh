#!/bin/bash
set -euo pipefail

NFS_MOUNT="${1:-}"
TEST_SIZE="${2:-10240}"  # MB

if [[ -z "$NFS_MOUNT" ]]; then
    echo "Usage: $0 <nfs-mount-point> [test-size-mb]"
    echo ""
    echo "Example: $0 /mnt/nfs-test 10240"
    exit 1
fi

if [[ ! -d "$NFS_MOUNT" ]]; then
    echo "❌ Mount point does not exist: $NFS_MOUNT"
    exit 1
fi

echo "=== NFS Performance Test ==="
echo "Mount: $NFS_MOUNT"
echo "Test size: ${TEST_SIZE} MB"
echo ""

TEST_FILE="$NFS_MOUNT/benchmark-$$.img"

cleanup() {
    rm -f "$TEST_FILE"
}
trap cleanup EXIT

# Sequential write
echo "--- Sequential Write ---"
dd if=/dev/zero of="$TEST_FILE" bs=1M count="$TEST_SIZE" conv=fdatasync 2>&1 | grep -E "copied|MB/s"

# Clear cache
sync
echo 3 | sudo tee /proc/sys/vm/drop_caches > /dev/null 2>&1 || true

# Sequential read
echo ""
echo "--- Sequential Read ---"
dd if="$TEST_FILE" of=/dev/null bs=1M count="$TEST_SIZE" 2>&1 | grep -E "copied|MB/s"

# Random I/O with fio (if installed)
if command -v fio &> /dev/null; then
    echo ""
    echo "--- Random Read (4K blocks) ---"
    fio --name=random-read \
        --ioengine=libaio \
        --rw=randread \
        --bs=4k \
        --size=1G \
        --numjobs=4 \
        --runtime=30 \
        --group_reporting \
        --directory="$NFS_MOUNT" \
        --output-format=normal | grep -E "IOPS|BW"

    echo ""
    echo "--- Random Write (4K blocks) ---"
    fio --name=random-write \
        --ioengine=libaio \
        --rw=randwrite \
        --bs=4k \
        --size=1G \
        --numjobs=4 \
        --runtime=30 \
        --group_reporting \
        --directory="$NFS_MOUNT" \
        --output-format=normal | grep -E "IOPS|BW"
else
    echo ""
    echo "⚠️  fio not installed. Skipping random I/O tests."
    echo "   Install: apt install fio"
fi

echo ""
echo "=== NFS Test Complete ==="
echo ""
echo "Expected results (1 Gbps network, RAID 5 NAS):"
echo "  Sequential write: 100-115 MB/s"
echo "  Sequential read: 110-120 MB/s"
echo "  Random read IOPS: 7000-9000"
echo "  Random write IOPS: 1500-2500"
echo ""
echo "Troubleshooting slow speeds:"
echo "  1. Check network first: ./network-test.sh <nas-ip>"
echo "  2. Check NAS disk performance (local test on NAS)"
echo "  3. Check NFS mount options: mount | grep nfs"
echo "     (should have: rsize=1048576,wsize=1048576)"
