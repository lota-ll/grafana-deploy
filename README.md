# EcoCharge Grafana Deployment - CTF Component

## Overview

Grafana monitoring dashboard for the EcoCharge CTF scenario. Provides infrastructure monitoring and contains intentional information disclosure vulnerability.

**Version:** 4.0.0  
**Port:** 3000  
**Network Zone:** DMZ (192.168.100.0/24)

## Vulnerability

### Default Credentials + Information Disclosure (FLAG #6)

**Credentials:** `admin` / `admin`

**Information Exposed:**
- Dashboard description contains internal network topology
- Internal service endpoints (CSMS, Hasura, Prometheus)
- Jump Host SSH details
- OT Network information

**FLAG:** `FLAG{gr4f4n4_d3f4ult_cr3ds}`

**Location:** Dashboard description in "EcoCharge CSMS Overview"

## Access

Grafana is NOT directly accessible from the Internet or Frontend zone.

**Access Method:**
1. Compromise Web Server
2. Pivot to Jump Host via SSH
3. Create SSH tunnel: `ssh -L 3000:192.168.100.30:3000 operator@192.168.100.40`
4. Access Grafana at `http://localhost:3000`

## Deployment

### Docker Compose

```bash
cd grafana-deploy-main
docker-compose up -d
```

### Manual

```bash
# Create directories
mkdir -p /var/lib/grafana
mkdir -p /etc/grafana/provisioning/datasources
mkdir -p /etc/grafana/provisioning/dashboards

# Copy configuration
cp grafana.ini /etc/grafana/
cp provisioning/datasources/* /etc/grafana/provisioning/datasources/
cp provisioning/dashboards/* /etc/grafana/provisioning/dashboards/
cp dashboards/* /var/lib/grafana/dashboards/

# Start Grafana
docker run -d \
  --name grafana \
  -p 3000:3000 \
  -v /var/lib/grafana:/var/lib/grafana \
  -v /etc/grafana:/etc/grafana \
  grafana/grafana:10.4.2
```

## Configuration

### Datasources

| Name | Type | URL | Purpose |
|------|------|-----|---------|
| Prometheus | prometheus | http://192.168.20.20:9090 | CSMS metrics |

### Dashboards

| Dashboard | Description |
|-----------|-------------|
| EcoCharge CSMS Overview | Main monitoring dashboard with **FLAG in description** |

## Network Configuration

| Parameter | Value |
|-----------|-------|
| IP Address | 192.168.100.30 |
| Port | 3000 |
| Zone | DMZ |
| Access From | Jump Host only (SSH tunnel) |
| Connects To | CSMS Prometheus (192.168.20.20:9090) |

## File Structure

```
grafana-deploy-main/
├── docker-compose.yml
├── grafana.ini
├── dashboards/
│   └── ecocharge-csms-overview.json    # Contains FLAG in description
├── provisioning/
│   ├── dashboards/
│   │   └── dashboards.yml
│   └── datasources/
│       └── datasources.yml
├── grafana-fixed/                       # Fixed version without vulnerabilities
└── README.md
```

## CTF Notes

### Discovery Path:
1. Player gains access to Jump Host
2. Creates SSH tunnel to Grafana
3. Logs in with default credentials (admin:admin)
4. Views dashboard description to find FLAG and internal info

### What Player Learns:
- CSMS internal endpoints
- Network topology confirmation
- Jump Host details (already known, but confirmed)

### Role in Attack Chain:
- **Optional** reconnaissance step
- Confirms information from other sources
- Provides additional context for CSMS attack

## Security Notice

This deployment contains intentional vulnerabilities for CTF purposes.
Do NOT use default credentials in production environments.

---

**Version:** 4.0.0  
**Last Updated:** February 2025
