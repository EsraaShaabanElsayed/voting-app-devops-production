# Voting Application - Complete Documentation

## 📋 Table of Contents

1. [Project Overview](#project-overview)
2. [Architecture](#architecture)
3. [Project Structure](#project-structure)
4. [Phase 1: Containerization & Docker Compose](#phase-1-containerization--docker-compose)
5. [Phase 2: Kubernetes Deployment](#phase-2-kubernetes-deployment)
6. [Security Implementation](#security-implementation)
7. [Network Policies](#network-policies)
8. [Deployment Guide](#deployment-guide)
9. [Verification & Testing](#verification--testing)
10. [Troubleshooting](#troubleshooting)
11. [Production Considerations](#production-considerations)

---

## 📖 Project Overview

A distributed voting application demonstrating microservices architecture, containerization, and Kubernetes orchestration. Users can vote between two options (typically "Cats" vs "Dogs"), with votes processed asynchronously through a message queue and results displayed in real-time.

### Technology Stack

| Component | Technology | Port |
|-----------|-----------|------|
| **Vote UI** | Python/Flask | 8080 |
| **Result UI** | Node.js/Express | 8081 |
| **Worker** | Python/Java/.NET | N/A (background) |
| **Cache** | Redis 7 | 6379 |
| **Database** | PostgreSQL 14 | 5432 |
| **Container Runtime** | Docker | - |
| **Orchestration** | Kubernetes (Minikube) | - |
| **Ingress** | NGINX Ingress Controller | 80|

---

## 🏗️ Architecture

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                      Ingress Controller                          │
│               (vote.com:80 / result.com:80)                      │
│          Features: Cookie affinity, WebSocket support            │
└───────────────┬─────────────────────────────┬───────────────────┘
                │                             │
        ┌───────▼────────┐            ┌──────▼──────────┐
        │  Vote Service  │            │ Result Service  │
        │   (ClusterIP)  │            │   (ClusterIP)   │
        │   Port: 80     │            │   Port: 80      │
        └───────┬────────┘            └──────┬──────────┘
                │                            │
        ┌───────▼────────┐            ┌──────▼──────────┐
        │  Vote Pods (2) │            │ Result Pods (2) │
        │   Port: 8080   │            │   Port: 8081    │
        └───────┬────────┘            └──────┬──────────┘
                │                            │
                ├────────────┐               │
                │            │               │
        ┌───────▼──────┐  ┌──▼──────────────▼─────┐
        │ Redis        │  │ PostgreSQL             │
        │ StatefulSet  │  │ StatefulSet            │
        │ (Headless)   │  │ (Headless)             │
        └───────▲──────┘  └──────▲─────────────────┘
                │                │
                └────┬───────────┘
                     │
              ┌──────▼────────┐
              │  Worker Pod   │
              │  (Processes   │
              │   votes)      │
              └───────────────┘
```

### Data Flow

1. **User casts vote** → Vote UI (port 8080)
2. **Vote stored** → Redis (queue/cache)
3. **Worker processes** → Reads from Redis, writes to PostgreSQL
4. **Results displayed** → Result UI reads from PostgreSQL (port 8081)

### Network Architecture

```
Frontend Network (External Access via Ingress):
- Vote Service: vote.com
- Result Service: result.com

Backend Network (NetworkPolicies):
- Redis: Accessible only by Vote + Worker
- PostgreSQL: Accessible only by Worker + Result
- Worker: No ingress, egress to Redis + PostgreSQL only
- DNS: All pods can query kube-system DNS
```

---

## 📁 Project Structure

```
voting-app/
├── docker-compose.yml           # Phase 1: Local development
├── healthchecks/                # Health check scripts
│   ├── redis.sh
│   └── postgres.sh
├── vote/                        # Vote service source
│   ├── Dockerfile
│   └── app/
├── result/                      # Result service source
│   ├── Dockerfile
│   └── app/
├── worker/                      # Worker service source
│   ├── Dockerfile
│   └── app/
└── k8s/                         # Phase 2: Kubernetes manifests
    ├── base/
    │   ├── namespace.yml        # voting-app namespace with PSA
    │   ├── ingress.yml          # Ingress for vote + result
    │   ├── configmaps/
    │   │   ├── vote-config.yaml
    │   │   ├── result-config.yaml
    │   │   └── worker-config.yaml
    │   ├── secrets/
    │   │   └── secrets.yml      # Database credentials (base64)
    │   ├── network-policies/
    │   │   ├── default-deny.yaml
    │   │   ├── vote-netpol.yml
    │   │   ├── result-netpol.yml
    │   │   ├── redis-netpol.yaml
    │   │   └── postgres-netpol.yml
    │   ├── vote/
    │   │   ├── deployment.yml
    │   │   ├── service.yml
    │   │   └── README.md
    │   ├── result/
    │   │   ├── deployment.yml
    │   │   ├── service.yml
    │   │   └── README.md
    │   └── worker/
    │       └── deployment.yml
    ├── redis/                   # Redis StatefulSet + Service
    │   ├── statefulset.yml
    │   ├── service.yml
    │   └── configmap.yml        # Health check script
    └── postgres/                # PostgreSQL StatefulSet + Service
        ├── statefulset.yml
        ├── service.yml
        └── configmap.yml        # Health check script
```

---

## ☸️ Phase 2: Kubernetes Deployment

### Prerequisites

- Minikube or Kubernetes cluster
- kubectl configured
- Helm 3.x (optional, for Redis/PostgreSQL deployment)
- Docker images pushed to registry (esraa114/*)

### Kubernetes Resources Overview

#### 1. Namespace (`base/namespace.yml`)


**Key Features:**
- Pod Security Admission (PSA) enforced at `restricted` level
- All pods must run as non-root with security contexts
- Strictest security policy for production readiness

#### 2. ConfigMaps (`base/configmaps/`)

**Purpose:** Store non-sensitive configuration that can be changed without rebuilding images


**Usage Pattern:**
- Non-sensitive data only (hostnames, ports, database names)
- Can be updated independently of deployments
- Mounted as environment variables using `envFrom`

#### 3. Secrets (`base/secrets/secrets.yml`)

**Purpose:** Store sensitive database credentials (base64 encoded)


**Creating/Updating Secrets:**
```bash
# Encode new values
echo -n "postgres" | base64
echo -n "postgres://postgres:postgres@db/postgres" | base64

# Decode existing values (for verification)
echo "cG9zdGdyZXM=" | base64 -d
```

**Security Note:** In production, use External Secrets Operator or Sealed Secrets instead of committing base64-encoded secrets to Git.

#### 4. Vote Service (`base/vote/`)
**Deployment File**
**Design Decisions:**
- **Replicas: 2** - Ensures high availability, survives single pod failure
- **imagePullPolicy: IfNotPresent** - Reduces registry load, suitable for dev
- **Health Probes** - HTTP checks on root path ensure service is responsive
- **Resource Limits** - Prevents resource exhaustion, ensures fair sharing
- **Non-root User (UID 1000)** - Security best practice, required by PSA

**Service Design:**
- **Type: ClusterIP** - Internal only, exposed via Ingress
- **Port mapping: 80→8080** - Standard HTTP port externally, custom port internally
- **Selector** - Routes traffic to pods with label `app: vote`

#### 5. Result Service (`base/result/`)

**deployment.yml - Similar to Vote with key differences:**


**Key Differences from Vote:**
- Uses **DATABASE_URL** connection string (Node.js pattern)
- Connects to PostgreSQL instead of Redis
- Port 8081 instead of 8080
- Health probes check port 8081


#### 6. Worker Service (`base/worker/`)

**Worker Characteristics:**
- **No Service definition** - Background worker, no incoming traffic
- **Replicas: 1** - Single instance to prevent duplicate vote processing
- **No health probes** - Background process, no HTTP endpoint (optional: add process-based checks)
- **Uses individual DB parameters** - Not DATABASE_URL (language-specific pattern)
- **Egress-only networking** - Connects to Redis and PostgreSQL

**Environment Variables:**
- Gets ConfigMap: `REDIS_HOST`, `REDIS_PORT`, `POSTGRES_HOST`, `POSTGRES_DB`
- Gets Secret: `POSTGRES_USER`, `POSTGRES_PASSWORD`
- **Does NOT use DATABASE_URL** - Uses parameters for connection pooling


#### 7. Redis StatefulSet (`k8s/redis/`)

**Why StatefulSet over Deployment?**

| Feature | StatefulSet | Deployment |
|---------|-------------|------------|
| **Pod Names** | Stable (redis-0) | Random (redis-7f8d9-abc12) |
| **Storage** | Persistent per pod | Ephemeral or shared |
| **Ordering** | Sequential start/stop | Parallel |
| **Network Identity** | Stable DNS | Changes on restart |
| **Use Case** | Databases, queues | Stateless apps |


**Key Configuration:**
- **Persistence enabled** - AOF (Append-Only File) for durability
- **Save policy** - Snapshot if 1 key changes in 60 seconds
- **Health checks** - Custom script using redis-cli
- **2Gi storage** - Sufficient for vote queue/cache
- **UID 999** - Default redis user in alpine image

**Headless Service (`clusterIP: None`):**
- Provides stable DNS: `redis-0.redis.voting-app.svc.cluster.local`
- No load balancing (direct pod access)
- Required for StatefulSet network identity



#### 8. PostgreSQL StatefulSet (`k8s/postgres/`)

**Service Name: `db`** - Matches Docker Compose for application compatibility

**statefulset.yml:**


**Key Configuration:**
- **PGDATA custom path** - Required for proper permissions with fsGroup
- **5Gi storage** - Adequate for application data
- **UID 999** - Default postgres user in alpine image
- **Health checks** - SQL query execution test

**service.yml:**

**configmap.yml (Health Check):**


#### 9. Ingress (`base/ingress.yml`)

**Purpose:** Expose vote and result services to external traffic



**Annotations Explained:**

| Annotation | Purpose | Value |
|------------|---------|-------|
| `rewrite-target` | URL rewriting | `/` (pass through) |
| `ssl-redirect` | Force HTTPS | `false` (dev environment) |
| `affinity` | Session persistence | `cookie` |
| `session-cookie-name` | Cookie name | `route` |
| `websocket-services` | WebSocket support | `result` (real-time updates) |
| `proxy-read-timeout` | Long-running connections | `3600` seconds (1 hour) |
| `proxy-send-timeout` | Upload timeout | `3600` seconds |

**Why Cookie Affinity?**
- Maintains session stickiness across multiple vote/result pods
- Ensures consistent user experience
- Required if application uses in-memory sessions

**Why WebSocket for Result?**
- Enables real-time vote count updates
- Maintains persistent connection to result service
- Reduces polling overhead

**DNS Setup:**

Add to `/etc/hosts` (Linux/Mac) or `C:\Windows\System32\drivers\etc\hosts` (Windows):
```
<MINIKUBE_IP> vote.com result.com
```

Get Minikube IP:
```bash
minikube ip
```

---

## 🔒 Security Implementation

### 1. Pod Security Standards (PSA)

**Enforcement Level:** `restricted` (most secure)

Applied at **namespace level**:
```yaml
metadata:
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
```

**PSA Levels:**

| Level | Description | Use Case |
|-------|-------------|----------|
| **privileged** | Unrestricted | Trusted workloads only |
| **baseline** | Minimally restrictive | Standard workloads |
| **restricted** | Heavily restricted | Security-critical apps ✅ |

**Restricted Policy Requirements:**
- ✅ All containers must run as non-root
- ✅ Security context must be defined
- ✅ All capabilities must be dropped
- ✅ No privilege escalation allowed
- ✅ Seccomp profile must be set
- ✅ No host namespaces, ports, or paths
- ✅ Read-only root filesystem (when possible)

### 2. Security Contexts

**Pod-level Security Context:**

Applied to all deployments/statefulsets:

```yaml
spec:
  securityContext:
    runAsNonRoot: true     # Prevent root execution
    runAsUser: 1000        # Specific UID (vote/result/worker)
    # OR
    runAsUser: 999         # For redis/postgres
    fsGroup: 1000          # File system group ownership
    seccompProfile:
      type: RuntimeDefault # Syscall filtering
```

**Container-level Security Context:**

```yaml
containers:
- name: app
  securityContext:
    allowPrivilegeEscalation: false  # Prevent sudo/setuid
    readOnlyRootFilesystem: false    # Apps need /tmp write
    runAsNonRoot: true
    runAsUser: 1000
    capabilities:
      drop:
      - ALL                           # Drop all Linux capabilities
```

**Why Drop ALL Capabilities?**

Linux capabilities grant fine-grained privileges. Dropping all prevents:
- Network packet injection
- Changing file ownership
- Loading kernel modules
- Accessing raw sockets
- And 30+ other privileges

### 3. Resource Limits

**Prevents:**
- Resource exhaustion attacks
- Noisy neighbor problems
- Cluster-wide outages

**Configuration:**

```yaml
resources:
  requests:
    memory: 128Mi    # Guaranteed allocation
    cpu: 100m        # 0.1 CPU cores
  limits:
    memory: 256Mi    # Hard limit (OOM kill if exceeded)
    cpu: 200m        # CPU throttling if exceeded
```

**Resource Allocation by Service:**

| Service | Memory Request | Memory Limit | CPU Request | CPU Limit |
|---------|---------------|--------------|-------------|-----------|
| Vote | 128Mi | 256Mi | 100m | 200m |
| Result | 128Mi | 256Mi | 100m | 200m |
| Worker | 128Mi | 256Mi | 100m | 200m |
| Redis | 128Mi | 256Mi | 100m | 200m |
| Postgres | 256Mi | 512Mi | 200m | 500m |

### 4. Secrets Management

**Current Implementation:**
- Base64-encoded Secrets in `secrets.yml`
- Mounted as environment variables via `secretKeyRef`

**Limitations:**
- ❌ Base64 is encoding, not encryption
- ❌ Secrets visible in YAML files
- ❌ Committing to Git exposes credentials
- ❌ No automatic rotation



## 🌐 Network Policies

### Overview

Network Policies implement **zero-trust networking** at Layer 3/4, controlling pod-to-pod communication based on labels and namespaces.

**Default-Deny Strategy:**
1. Block all traffic by default
2. Explicitly allow required communication
3. Minimize attack surface

### Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                     Internet/User                            │
└─────────────────────────┬───────────────────────────────────┘
                          │
                ┌─────────▼──────────┐
                │ Ingress Controller │
                │ (ingress-nginx NS) │
                └─────────┬──────────┘
                          │
        ┌─────────────────┼─────────────────┐
        │                 │                 │
    ┌───▼────┐      ┌────▼─────┐     ┌────▼─────┐
    │  Vote  │      │  Result  │     │  Worker  │
    │  Pods  │      │   Pods   │     │   Pod    │
    └───┬────┘      └────┬─────┘     └─┬──────┬─┘
        │                │               │      │
        ├────────────────┼───────────────┤      │
        │                │               │      │
    ┌───▼────┐      ┌────▼──────────────▼──────▼──┐
    │ Redis  │      │      PostgreSQL              │
    │  Pod   │      │         Pod                  │
    └────────┘      └──────────────────────────────┘

Legend:
→ Allowed Traffic
╳ Blocked Traffic
```

### 1. Default Deny All (`base/network-policies/default-deny.yaml`)

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: voting-app
spec:
  podSelector: {}    # Applies to all pods in namespace
  policyTypes:
  - Ingress          # Block all incoming traffic
  - Egress           # Block all outgoing traffic
```

**Effect:**
- Blocks ALL traffic by default
- Must create explicit allow rules
- Follows principle of least privilege

**Testing:**
```bash
# Without allow rules, this should fail:
kubectl exec -it vote-pod -n voting-app -- curl redis:6379
# Output: Connection timeout
```

### 2. Vote Network Policy (`base/network-policies/vote-netpol.yml`)



**Traffic Flow:**
```
Internet → Ingress (✅) → Vote:8080 (✅) → Redis:6379 (✅)
Vote → Postgres:5432 (❌ Blocked)
Vote → Worker (❌ No direct communication needed)
```

**Rationale:**
- Vote only needs Redis for storing votes
- No database access (worker handles that)
- DNS required for service discovery

### 3. Result Network Policy (`base/network-policies/result-netpol.yml`)


**Traffic Flow:**
```
Internet → Ingress (✅) → Result:8081 (✅) → Postgres:5432 (✅)
Result → Redis:6379 (❌ Blocked - no need)
Result → Vote (❌ No direct communication)
```

**Rationale:**
- Result only reads from PostgreSQL
- No Redis access needed
- WebSocket support via Ingress annotations

### 4. Worker Network Policy (`base/network-policies/worker-netpol.yml`)


**Traffic Flow:**
```
Worker → Redis:6379 (✅ Read votes)
Worker → Postgres:5432 (✅ Write results)
Internet → Worker (❌ No ingress allowed)
```

**Rationale:**
- Worker is pure background processor
- No incoming connections needed
- Bridge between Redis and PostgreSQL

### 5. Redis Network Policy (`base/network-policies/redis-netpol.yaml`)


**Traffic Flow:**
```
Vote → Redis:6379 (✅ Write votes)
Worker → Redis:6379 (✅ Read votes)
Result → Redis:6379 (❌ Blocked - no need)
Internet → Redis (❌ No external access)
```

**Security Benefits:**
- Redis isolated from internet
- Only authorized pods can access
- No egress restrictions (Redis doesn't initiate connections)

### 6. PostgreSQL Network Policy (`base/network-policies/postgres-netpol.yml`)



**Traffic Flow:**
```
Worker → Postgres:5432 (✅ Write votes)
Result → Postgres:5432 (✅ Read votes)
Vote → Postgres:5432 (❌ Blocked - uses Redis)
Internet → Postgres (❌ No external access)
```

**Security Benefits:**
- Database completely isolated
- Only worker and result have access
- No direct internet exposure

### Network Policy Testing

#### Verify Policies Applied

```bash
# List all policies
kubectl get networkpolicies -n voting-app

```
![alt text](<Screenshot from 2025-11-22 13-01-57.png>)


## 🚀 Deployment Guide

### Quick Start (Complete Deployment)

#### Prerequisites

```bash
# Verify prerequisites
minikube version   # Should be v1.30+
kubectl version    # Should be v1.28+
helm version       # Should be v3.12+

# Start Minikube with sufficient resources
minikube start --cpus=4 --memory=8192 --driver=docker

# Enable required addons
minikube addons enable ingress


#### Step-by-Step Deployment

```bash
# 1. Create namespace and base resources
kubectl apply -f k8s/base/namespace.yml
kubectl apply -f k8s/base/configmaps/
kubectl apply -f k8s/base/secrets/

# 2. Deploy Redis StatefulSet
kubectl apply -f k8s/redis/

# 3. Deploy PostgreSQL StatefulSet
kubectl apply -f k8s/postgres/


# 5. Deploy application services
kubectl apply -f k8s/base/vote/
kubectl apply -f k8s/base/result/
kubectl apply -f k8s/base/worker/


# 7. Apply NetworkPolicies
kubectl apply -f k8s/base/network-policies/

# 8. Deploy Ingress
kubectl apply -f k8s/base/ingress.yml

# 9. Configure local DNS
echo "$(minikube ip) vote.com result.com" | sudo tee -a /etc/hosts

# 10. Verify deployment
kubectl get all -n voting-app
kubectl get ingress -n voting-app
```
![alt text](<Screenshot from 2025-11-22 13-05-40.png>)
![alt text](<Screenshot from 2025-11-22 13-06-06.png>)
#### Automated Deployment Script


## ✅ Verification & Testing

### Test Application Flow

#### 1. Cast a Vote

```bash
# Open vote interface
open http://vote.com  # Mac
xdg-open http://vote.com  # Linux

# Click "Cats" or "Dogs"
```
![alt text](<Screenshot from 2025-11-22 13-07-35.png>)

#### 5. View Results

open http://result.com
![alt text](<Screenshot from 2025-11-22 13-22-51.png>)



---


