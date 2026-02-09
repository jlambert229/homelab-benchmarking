#!/bin/bash
set -euo pipefail

SERVER="${1:-}"
DURATION="${2:-30}"

if [[ -z "$SERVER" ]]; then
    echo "Usage: $0 <server-ip> [duration-seconds]"
    echo ""
    echo "Example: $0 192.168.2.129 30"
    exit 1
fi

echo "=== Network Performance Test ==="
echo "Server: $SERVER"
echo "Duration: ${DURATION}s"
echo ""

# Check if iperf3 is installed
if ! command -v iperf3 &> /dev/null; then
    echo "❌ iperf3 not installed."
    echo ""
    echo "Install:"
    echo "  apt install iperf3        # Debian/Ubuntu"
    echo "  yum install iperf3        # RHEL/CentOS"
    echo "  brew install iperf3       # macOS"
    exit 1
fi

echo "Make sure iperf3 server is running on $SERVER:"
echo "  iperf3 -s"
echo ""
read -p "Press Enter to start test..."

echo ""
echo "--- TCP Bandwidth Test ---"
iperf3 -c "$SERVER" -t "$DURATION" -i 5

echo ""
echo "--- TCP Bandwidth (10 parallel streams) ---"
iperf3 -c "$SERVER" -P 10 -t 10

echo ""
echo "--- UDP Bandwidth & Packet Loss ---"
iperf3 -c "$SERVER" -u -b 1G -t 10

echo ""
echo "=== Network Test Complete ==="
echo ""
echo "Expected results (1 Gbps network):"
echo "  TCP: 900-940 Mbps"
echo "  UDP: <1ms jitter, 0% packet loss"
echo ""
echo "Troubleshooting low speeds:"
echo "  1. Check link speed: ethtool eth0 | grep Speed"
echo "  2. Check duplex: ethtool eth0 | grep Duplex  (should be Full)"
echo "  3. Check for errors: ethtool -S eth0 | grep -i error"
