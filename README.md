# GCP Hybrid Network — Terraform Architecture

This Terraform configuration provisions a **GCP Hybrid Network** using **Network Connectivity Center (NCC)** as the hub-and-spoke backbone. A **Cloud Router** with **Dedicated Interconnect** attachments and **BGP route policies** provides redundant hybrid connectivity between on-premises and GCP workloads across two VPCs.

> **Diagram legend:** Solid borders and solid arrows = **deployed**. Dashed borders and dashed arrows (`- - ->`) = **planned / not yet provisioned**.

---

## Architecture Diagram

```mermaid
graph TD
    OP["On-Premises BGP Router"]
    IC_ASH["ashburn-ic\nDEDICATED · Domain 1 · 10 Gbps"]
    IC_CHI["chicago-ic\nDEDICATED · Domain 2 · 10 Gbps"]

    subgraph GCP["GCP — us-central1"]

        subgraph SPOKE_VPC["hybrid-spoke-vpc"]
            SUBNET1["hybrid-spoke-subnet\n10.1.1.0/24"]
            FW1["hub-allow-internal\nIngress · Allow ALL\nsrc 10.1.1.0/24 · 10.1.2.0/24"]
            ROUTER["hybrid-router\nCloud Router · BGP"]
            RP["prepend-on-prefix-match\nEXPORT policy\nAS-path prepend ×5 → 10.2.2.0/24\naccept() all others"]
            IF1["router-ashburn-interface-01\n169.254.10.1/30"]
            IF2["router-chicago-interface-01\n169.254.20.1/30"]
            BP1["ashburn-peer\n169.254.10.2"]
            BP2["chicago-peer\n169.254.20.2"]
        end

        subgraph SVC_VPC["hybrid-service-vpc"]
            SUBNET2["hybrid-service-subnet\n10.1.2.0/24"]
            FW2["spoke-allow-internal\nIngress · Allow ALL\nsrc 10.1.1.0/24 · 10.1.2.0/24"]
        end

        subgraph NCC_LAYER["Network Connectivity Center"]
            HUB["ncc-hub · global"]
            SP1["hybrid-spoke · global"]
            SP2["hybrid-service-spoke · global"]
        end

        %% ── Deployed connections ──────────────────────────────────
        ROUTER --> RP
        SPOKE_VPC -->|NCC linked vpc| SP1 --> HUB
        SVC_VPC  -->|NCC linked vpc| SP2 --> HUB

        %% ── Planned connections (dashed) ──────────────────────────
        IC_ASH -.->|VLAN attachment| IF1
        IC_CHI -.->|VLAN attachment| IF2
        IF1 -.-> BP1
        IF2 -.-> BP2
        BP1 -.->|export policy| RP
        BP2 -.->|export policy| RP
        SUBNET1 -.->|allow-internal| FW1
        SUBNET2 -.->|allow-internal| FW2
    end

    %% ── Planned on-prem connections (dashed) ─────────────────────
    OP -.->|physical circuit| IC_ASH
    OP -.->|physical circuit| IC_CHI

    %% ── Node styles: planned resources (dashed border, grey fill) ─
    style OP        stroke-dasharray:5 5,fill:#f4f4f4,color:#555
    style IC_ASH    stroke-dasharray:5 5,fill:#f4f4f4,color:#555
    style IC_CHI    stroke-dasharray:5 5,fill:#f4f4f4,color:#555
    style IF1       stroke-dasharray:5 5,fill:#f4f4f4,color:#555
    style IF2       stroke-dasharray:5 5,fill:#f4f4f4,color:#555
    style BP1       stroke-dasharray:5 5,fill:#f4f4f4,color:#555
    style BP2       stroke-dasharray:5 5,fill:#f4f4f4,color:#555
    style FW1       stroke-dasharray:5 5,fill:#f4f4f4,color:#555
    style FW2       stroke-dasharray:5 5,fill:#f4f4f4,color:#555
```

---

## Deployment Status

### Deployed

| Resource | Type | Scope |
|---|---|---|
| `hybrid-spoke-vpc` | VPC Network (custom) | Global |
| `hybrid-spoke-subnet` | Subnetwork | us-central1 · 10.1.1.0/24 |
| `hybrid-service-vpc` | VPC Network (custom) | Global |
| `hybrid-service-subnet` | Subnetwork | us-central1 · 10.1.2.0/24 |
| `ncc-hub` | NCC Hub | Global |
| `hybrid-spoke` | NCC Spoke | Global — linked to `hybrid-spoke-vpc` |
| `hybrid-service-spoke` | NCC Spoke | Global — linked to `hybrid-service-vpc` |
| `hybrid-router` | Cloud Router | us-central1 · BGP ASN configured |
| `prepend-on-prefix-match` (Term 1) | Route Policy — EXPORT | us-central1 · AS-path prepend ×5 for 10.2.2.0/24 |

### Planned (Not Yet Provisioned)

| Resource | Type | Dependency |
|---|---|---|
| `ashburn-ic` | Dedicated Interconnect Attachment — Domain 1 · 10 Gbps | Physical circuit must exist first |
| `chicago-ic` | Dedicated Interconnect Attachment — Domain 2 · 10 Gbps | Physical circuit must exist first |
| `router-ashburn-interface-01` | Router Interface — 169.254.10.1/30 | `ashburn-ic` |
| `router-chicago-interface-01` | Router Interface — 169.254.20.1/30 | `chicago-ic` |
| `ashburn-peer` | BGP Peer — 169.254.10.2 | `router-ashburn-interface-01` |
| `chicago-peer` | BGP Peer — 169.254.20.2 | `router-chicago-interface-01` |
| `prepend-on-prefix-match` (Term 2) | Route Policy Term — accept() all | BGP peers active |
| `hub-allow-internal` | Firewall Rule — `hybrid-spoke-vpc` | IAM permission: `compute.firewalls.create` |
| `spoke-allow-internal` | Firewall Rule — `hybrid-service-vpc` | IAM permission: `compute.firewalls.create` |

---

## Network Topology

### Hub-and-Spoke via NCC

Both VPCs attach to a single globally-scoped NCC hub as VPC network spokes, enabling transitive routing between `hybrid-spoke-vpc` and `hybrid-service-vpc` without direct VPC peering.

```
hybrid-spoke-vpc ──hybrid-spoke──▶  ncc-hub  ◀──hybrid-service-spoke──  hybrid-service-vpc
```

### Hybrid Connectivity (Dedicated Interconnect — Planned)

The Cloud Router is designed to terminate two Dedicated Interconnect VLAN attachments in separate availability domains across two geographic locations, providing geographic HA redundancy for the on-premises path.

```
On-Premises BGP Router
   ├── Ashburn  (Domain 1) ─ 10G ─▶  router-ashburn-interface-01 ─▶  ashburn-peer
   └── Chicago  (Domain 2) ─ 10G ─▶  router-chicago-interface-01 ─▶  chicago-peer
```

### BGP Route Policy — Export (AS-Path Prepend)

The `prepend-on-prefix-match` export policy attaches to both BGP peers and selectively manipulates outbound route advertisements to steer inbound on-premises traffic.

| Term | Priority | Match | Action |
|---|---|---|---|
| 1 ✓ deployed | 100 | `destination == 10.2.2.0/24` | AS-path prepend ×5 — deprioritises this prefix on the peering path |
| 2 ○ planned | 200 | all other destinations | `accept()` — advertise all other prefixes normally |

### Inter-VPC Firewall (Planned)

Both VPCs will carry ingress rules permitting all protocols between the two subnets once the required IAM permission (`compute.firewalls.create`) is available.

| Rule | Network | Source Ranges |
|---|---|---|
| `hub-allow-internal` | `hybrid-spoke-vpc` | 10.1.1.0/24, 10.1.2.0/24 |
| `spoke-allow-internal` | `hybrid-service-vpc` | 10.1.1.0/24, 10.1.2.0/24 |

---

## IP Address Plan

| Segment | CIDR | Location |
|---|---|---|
| Hybrid Spoke Subnet | 10.1.1.0/24 | hybrid-spoke-vpc · us-central1 |
| Hybrid Service Subnet | 10.1.2.0/24 | hybrid-service-vpc · us-central1 |
| Ashburn Router Link-Local | 169.254.10.1/30 | hybrid-router ↔ Ashburn IC |
| Chicago Router Link-Local | 169.254.20.1/30 | hybrid-router ↔ Chicago IC |
| On-Premises Target Prefix | 10.2.2.0/24 | External — on-premises |

---

## Provisioning Sequence

```mermaid
flowchart LR
    subgraph PHASE1["Phase 1 — Deployed"]
        P1A["VPC Networks"]
        P1B["Subnets"]
        P1C["NCC Hub + Spokes"]
        P1D["Cloud Router + BGP ASN"]
        P1E["Route Policy\nTerm 1"]
        P1A --> P1B --> P1C
        P1A --> P1D --> P1E
    end

    subgraph PHASE2["Phase 2 — Planned"]
        P2A["Physical Circuits\nAshburn + Chicago"]
        P2B["IC Attachments\nashburn-ic · chicago-ic"]
        P2C["Router Interfaces"]
        P2D["BGP Peers"]
        P2E["Route Policy\nTerm 2 — accept()"]
        P2F["Firewall Rules"]
        P2A --> P2B --> P2C --> P2D --> P2E
        P2C --> P2F
    end

    PHASE1 --> PHASE2
```

---

## Terraform Providers

| Provider | Version |
|---|---|
| `hashicorp/google` | >= 7.18.0 |
| `hashicorp/tls` | proxy via environment |

---

## File Structure

| File | Purpose |
|---|---|
| `providers.tf` | Google & TLS provider configuration |
| `variables.tf` | Input variable declarations |
| `terraform.tfvars` | Variable value assignments |
| `network.tf` | VPC networks, subnets, NCC hub and spokes |
| `router.tf` | Cloud Router, router interfaces, BGP peers, route policies, and Dedicated Interconnect attachments |
| `firewall.tf` | Inter-VPC ingress firewall rules |
| `import.tf` | Import blocks for pre-existing GCP resources |
