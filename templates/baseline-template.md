# Homelab Performance Baseline

**Date:** YYYY-MM-DD  
**Hardware:** Describe your hardware

## Network Performance

### TCP Bandwidth

| Source | Destination | Bandwidth | Notes |
|--------|-------------|-----------|-------|
| Proxmox | Synology NAS | 940 Mbps | Expected max for 1 Gbps |
| K8s Worker 1 | Synology NAS | 935 Mbps | |
| K8s Worker 2 | Synology NAS | 938 Mbps | |

### UDP Performance

| Test | Jitter | Packet Loss | Notes |
|------|--------|-------------|-------|
| Proxmox → NAS | 0.012 ms | 0% | |

## Storage Performance (NFS)

### Synology NAS - Local Disk

| Test | Speed | Notes |
|------|-------|-------|
| Sequential write | 220 MB/s | RAID 5 ceiling |
| Sequential read | 280 MB/s | RAID 5 ceiling |

### NFS from Proxmox

| Test | Speed | IOPS | Notes |
|------|-------|------|-------|
| Sequential write | 110 MB/s | - | Network-limited |
| Sequential read | 115 MB/s | - | Network-limited |
| Random read (4K) | 33 MB/s | 8,500 | Good for RAID 5 |
| Random write (4K) | 7 MB/s | 1,800 | RAID 5 write penalty |

### K8s PVC (NFS-backed)

| Test | Speed | Notes |
|------|-------|-------|
| Sequential write | 108 MB/s | CSI overhead ~2% |
| Sequential read | 113 MB/s | |

## CPU Performance

### Proxmox Host

| Test | Events/sec | Notes |
|------|------------|-------|
| Single-threaded | 1,850 | Sufficient for etcd |
| Multi-threaded (4 cores) | 7,200 | ~2 Plex transcodes |

### K8s Worker VMs

| Test | Events/sec | Notes |
|------|------------|-------|
| Single-threaded | 1,200 | VM overhead ~35% |
| Multi-threaded (2 vCPU) | 2,400 | ~1 Plex transcode |

## Interpretation

### Network
- **900-940 Mbps TCP:** Expected max for 1 Gbps network
- **<1 ms jitter, 0% packet loss:** Excellent

### Storage
- **NFS 100-115 MB/s sequential:** Network-limited (expected)
- **8000+ random read IOPS:** Good for spinning disks in RAID 5
- **1500-2000 random write IOPS:** Normal for RAID 5 (write penalty)

### CPU
- **>1500 single-thread:** Good for Kubernetes etcd
- **Linear scaling with cores:** No thermal throttling

## Next Review

**Quarterly:** Re-run benchmarks and compare
**After changes:** Hardware upgrade, network changes, firmware updates

## Troubleshooting Thresholds

If future benchmarks show:

| Metric | Threshold | Action |
|--------|-----------|--------|
| TCP bandwidth | <400 Mbps | Check link speed, duplex, cables |
| NFS sequential | <70 MB/s | Check network first, then NAS load |
| Random IOPS | <5000 | Check for disk failures, RAID rebuild |
| CPU single-thread | 50% drop | Check for throttling, VM resource limits |
