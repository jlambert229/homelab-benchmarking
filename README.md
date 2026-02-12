# homelab-benchmarking

![pre-commit](https://github.com/jlambert229/homelab-benchmarking/actions/workflows/pre-commit.yml/badge.svg)
![GitHub last commit](https://img.shields.io/github/last-commit/jlambert229/homelab-benchmarking)

Performance testing and benchmarking scripts for homelab infrastructure.

**Blog post:** [Homelab Network Performance Testing and Benchmarking](https://foggyclouds.io/post/homelab-network-benchmarking/)

## Purpose

Establish performance baselines for your homelab to:
- **Detect degradation** - Know when something breaks
- **Identify bottlenecks** - Find weak links before they cause problems
- **Justify upgrades** - Prove you need faster hardware (or prove you don't)
- **Troubleshoot issues** - "It used to get 900 Mbps, now it's 100 Mbps"

## Tests Included

### Network Performance
- TCP bandwidth between nodes
- UDP bandwidth, jitter, and packet loss
- Parallel stream testing (multi-user simulation)

### Storage Performance
- Sequential read/write (dd)
- Random I/O (fio)
- NFS-specific testing
- K8s PVC performance

### CPU Performance
- Single-threaded benchmarks
- Multi-threaded scaling
- Sustained load testing with thermal monitoring

## Prerequisites

Install testing tools:

```bash
# Debian/Ubuntu
sudo apt update
sudo apt install iperf3 fio sysbench stress-ng lm-sensors

# RHEL/CentOS
sudo yum install iperf3 fio sysbench stress-ng lm_sensors

# macOS
brew install iperf3 fio sysbench stress-ng
```

## Quick Start

### Full Benchmark Suite

```bash
# Configure your environment
export NAS_IP="192.168.2.10"
export NFS_MOUNT="/mnt/nfs-test"

# Run all tests
./full-benchmark.sh
```

Results saved to `./results/benchmark-<timestamp>.txt`

### Individual Tests

**Network:**

```bash
# Start server on target machine
iperf3 -s

# Run client test
./network-test.sh 192.168.2.10
```

**NFS:**

```bash
# Mount NFS share first
sudo mkdir -p /mnt/nfs-test
sudo mount -t nfs 192.168.2.10:/volume1/nfs01 /mnt/nfs-test

# Run test
./nfs-test.sh /mnt/nfs-test
```

**CPU:**

```bash
./cpu-test.sh 30  # 30 second tests
```

## Interpreting Results

### Network (1 Gbps)

| Result | Rating | Notes |
|--------|--------|-------|
| 900-940 Mbps | ✅ Perfect | TCP overhead ~6% |
| 700-900 Mbps | ⚠️ Good | Light interference |
| 400-700 Mbps | ❌ Poor | Duplex mismatch, cable issue |
| <400 Mbps | ❌ Bad | Serious problem |

### NFS Sequential (1 Gbps network)

| Result | Rating | Notes |
|--------|--------|-------|
| 100-115 MB/s | ✅ Expected | Network-limited |
| 70-100 MB/s | ⚠️ Good | Some overhead |
| <70 MB/s | ❌ Poor | Investigate |

### NFS Random IOPS (RAID 5 HDD)

| Metric | Expected | Notes |
|--------|----------|-------|
| Random read | 7000-9000 | Good for spinning disks |
| Random write | 1500-2500 | RAID 5 write penalty |

### CPU (Modern x86_64)

| Test | Good | Adequate | Slow |
|------|------|----------|------|
| Single-thread | 1500+ | 1000-1500 | <1000 |

## Creating Your Baseline

1. **Run full benchmark:**
   ```bash
   ./full-benchmark.sh
   ```

2. **Document results:**
   - Copy `templates/baseline-template.md` to `results/baseline-YYYY-MM-DD.md`
   - Fill in your results
   - Note hardware configuration

3. **Schedule quarterly re-runs:**
   ```bash
   # Cron: First Sunday of every quarter at 3am
   0 3 1 */3 * cd /path/to/homelab-benchmarking && ./full-benchmark.sh
   ```

4. **Compare over time:**
   ```bash
   diff results/benchmark-20260208.txt results/benchmark-20260508.txt
   ```

## Troubleshooting Playbook

### Network is slow

1. **Baseline test:** `./network-test.sh <server-ip>`
2. **Check link speed:**
   ```bash
   ethtool eth0 | grep Speed    # Should be 1000Mb/s
   ethtool eth0 | grep Duplex   # Should be Full
   ```
3. **Check for errors:**
   ```bash
   ethtool -S eth0 | grep -i error
   ```
4. **Test different times** - Congestion during peak hours?

### NFS is slow

1. **Network first:** Test with iperf3 to NAS
2. **NFS vs local:** Compare dd speeds on NFS vs local NAS disk
3. **NAS CPU:** SSH to NAS, check CPU during transfer (top)
4. **Mount options:**
   ```bash
   mount | grep nfs
   # Should have: rsize=1048576,wsize=1048576
   ```

### Plex is buffering

Test each layer:

1. **Network:** iperf3 from Plex server to client
   - Need: >50 Mbps for 1080p, >100 Mbps for 4K
2. **Storage:** fio test on media PVC
   - Need: >50 MB/s sequential read
3. **CPU:** Check Plex transcoding load
   ```bash
   kubectl top pod -n media -l app.kubernetes.io/name=plex
   ```
4. **Client:** Is it forcing transcode? (Check Plex dashboard)

## Automated Regression Testing

Run benchmarks after major changes:

```bash
# Before upgrade
./full-benchmark.sh
mv results/benchmark-*.txt results/before-upgrade.txt

# After upgrade
./full-benchmark.sh
mv results/benchmark-*.txt results/after-upgrade.txt

# Compare
diff results/before-upgrade.txt results/after-upgrade.txt
```

## Common Findings

### "I thought I needed 10 GbE"

Benchmarks showed:
- Plex 4K streams: 60-80 Mbps
- NFS writes during backups: 110 MB/s (near 1 Gbps max)
- Total household usage: <300 Mbps peak

**Result:** 1 Gbps is sufficient. Saved $800 on NICs and switches.

### "Why is IOPS so low?"

Random 4K reads: 8,500 IOPS = 33 MB/s  
Sequential reads: 115 MB/s

**Insight:** Databases on NFS will be slow. Use local SSDs or iSCSI for latency-sensitive apps.

### "My network is congested"

iperf3 at 3am: 940 Mbps  
iperf3 at 8pm: 450 Mbps

**Cause:** Kids streaming 4K video, automated backups running simultaneously.

**Solution:** QoS or schedule backups for off-peak hours.

## Results Directory Structure

```
results/
├── baseline-2026-02-08.md       # Documented baseline
├── benchmark-20260208_030000.txt
├── benchmark-20260508_030000.txt
└── ...
```

Keep historical results to track degradation over time.

## Integration with Monitoring

Export results to Grafana/Prometheus for visualization:

```bash
# Convert results to metrics (example)
cat results/benchmark-*.txt | grep "Mbits/sec" | \
  awk '{print "network_bandwidth_mbps " $7}'
```

Or use [Uptime Kuma](https://github.com/YOUR-USERNAME/k8s-uptime-kuma) for alerting on threshold violations.

## References

- [iperf3 Documentation](https://iperf.fr/)
- [fio Documentation](https://fio.readthedocs.io/)
- [sysbench Documentation](https://github.com/akopytov/sysbench)
- [Blog post: Homelab Performance Testing](https://foggyclouds.io/post/homelab-network-benchmarking/)

## License

MIT
