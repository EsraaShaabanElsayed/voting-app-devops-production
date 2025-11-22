![alt text](<Screenshot from 2025-11-22 22-25-34.png>)

[![CI/CD](https://github.com/esraashaabanelsayed/voting-app-devops-production/actions/workflows/ci-cd.yml/badge.svg)](https://github.com/esraashaabanelsayed/voting-app-devops-production/actions)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-1.28+-326CE5?logo=kubernetes&logoColor=white)](https://kubernetes.io/)
[![Docker](https://img.shields.io/badge/Docker-Compose-2496ED?logo=docker&logoColor=white)](https://www.docker.com/)
[![Helm](https://img.shields.io/badge/Helm-3.x-0F1689?logo=helm&logoColor=white)](https://helm.sh/)
[![Security](https://img.shields.io/badge/Security-PSA%20Restricted-success)](https://kubernetes.io/docs/concepts/security/pod-security-standards/)

![CI/CD Status](https://github.com/esraashaabanelsayed/voting-app-devops-production/actions/workflows/ci-cd.yml/badge.svg)
# Voting Application - Cloud-Native Microservices Platform
A production-ready distributed voting application demonstrating enterprise-grade containerization, Kubernetes orchestration, CI/CD automation, and comprehensive security practices.




---

## 📋 Table of Contents

- [Overview](#overview)
- [What I Built](#what-i-built)
- [Architecture](#architecture)
- [Technology Stack](#technology-stack)
- [Key Features](#key-features)
- [Project Structure](#project-structure)
- [Getting Started](#getting-started)
- [Deployment Options](#deployment-options)
- [CI/CD Pipeline](#cicd-pipeline)
- [Security Implementation](#security-implementation)
- [Network Architecture](#network-architecture)
- [Monitoring & Observability](#monitoring--observability)
- [Key Challenges & Solutions](#key-challenges--solutions)
- [Testing](#testing)
- [Production Readiness](#production-readiness)
- [Documentation](#documentation)
- [Lessons Learned](#lessons-learned)
- [Future Roadmap](#future-roadmap)

---

## 🎯 Overview

This project implements a distributed voting application where users vote between two options (Cats vs Dogs). Votes are processed asynchronously through Redis message queues and persisted in PostgreSQL, with real-time results streamed via WebSockets.

### The Challenge

Build a production-grade microservices platform demonstrating:
- **Multi-phase deployment**: Docker Compose → Kubernetes → CI/CD Automation
- **Security-first approach**: Pod Security Standards, NetworkPolicies, vulnerability scanning
- **Production readiness**: High availability, persistence, scalability, observability

### The Solution

A fully automated, secure, and scalable cloud-native application featuring:
- ✅ **5 microservices** orchestrated seamlessly
- ✅ **Automated CI/CD pipeline** with GitHub Actions
- ✅ **Container security scanning** with Trivy
- ✅ **Zero-trust networking** with NetworkPolicies
- ✅ **Infrastructure as Code** with Kubernetes manifests and Helm
- ✅ **High availability** with multiple replicas and health checks
- ✅ **Production-grade database** management with StatefulSets
- ✅ **Real-time updates** via WebSocket connections

---

## 🚀 What I Built

### Phase 1: Containerization & Local Development
- ✅ **Dockerized all services** with multi-stage builds for optimization
- ✅ **Docker Compose orchestration** with health checks and dependency management
- ✅ **Two-tier networking** for frontend/backend isolation
- ✅ **Persistent volumes** for data durability


### Phase 2: Kubernetes Production Deployment
- ✅ **Complete Kubernetes manifests** for all services
- ✅ **StatefulSets** for stateful workloads (Redis, PostgreSQL)
- ✅ **Pod Security Admission** at restricted level (strictest enforcement)
- ✅ **NetworkPolicies** implementing zero-trust architecture
- ✅ **Helm charts** for production database management
- ✅ **NGINX Ingress** with cookie affinity and WebSocket support
- ✅ **ConfigMaps and Secrets** for configuration management
- ✅ **Comprehensive health probes** (liveness and readiness)
- ✅ **Resource quotas** to prevent resource exhaustion
- ✅ **Service aliases** solving Helm naming challenges

### Phase 3: CI/CD Automation
- ✅ **GitHub Actions pipeline** for automated build and deployment
- ✅ **Multi-service matrix builds** for parallel processing
- ✅ **Container image scanning** with Trivy security analysis
- ✅ **Automated deployment** to Minikube for testing
- ✅ **Smoke tests** validating application functionality
- ✅ **SARIF security reports** uploaded to GitHub Security tab
- ✅ **Automatic image tagging** with commit SHA for traceability

### Key Achievements
- 🏆 **100% non-root containers** - All services run as unprivileged users (UID 1000/999)
- 🏆 **Zero-trust networking** - Default-deny with explicit allow rules
- 🏆 **Production-grade security** - PSA restricted, capabilities dropped, seccomp enabled
- 🏆 **Automated vulnerability scanning** - Security issues detected and reported
- 🏆 **High availability** - Multiple replicas with sophisticated health checks
- 🏆 **Helm integration** - Solved service naming challenges with creative solutions
- 🏆 **Full CI/CD automation** - From code commit to deployed application

---

## 🏗️ Architecture

### System Architecture

The application follows a microservices architecture with clear separation of concerns:

**Frontend Tier:**
- Vote Service (Python/Flask) - User voting interface
- Result Service (Node.js/Express) - Real-time results dashboard

**Backend Tier:**
- Worker Service (.NET/C#) - Asynchronous vote processor
- Redis (Message Queue) - Vote queue and caching layer
- PostgreSQL (Database) - Persistent vote storage

**Infrastructure:**
- NGINX Ingress Controller - External access with load balancing
- Kubernetes - Container orchestration and service mesh
- Helm - Package management for databases

### Data Flow

1. **User submits vote** → Vote UI captures selection
2. **Vote queued** → Pushed to Redis list (LPUSH operation)
3. **Worker processes** → Polls Redis (LPOP), validates, inserts/updates PostgreSQL
4. **Results computed** → Result UI queries PostgreSQL, aggregates vote counts
5. **Real-time streaming** → WebSocket connection pushes live updates to browsers

### Network Topology

The application implements a zero-trust network architecture:

**External Network:**
- Internet/Users → Ingress Controller → Vote/Result Services

**Internal Network (Isolated):**
- Vote → Redis (write votes)
- Worker → Redis (read votes) + PostgreSQL (write results)
- Result → PostgreSQL (read results)
- All Services → DNS (service discovery)

**Blocked Communications:**
- Vote ↛ PostgreSQL (enforced by NetworkPolicy)
- Result ↛ Redis (enforced by NetworkPolicy)
- Databases ↛ Internet (no egress allowed)

---

## 💻 Technology Stack

### Application Layer

| Component | Technology | Version | Purpose |
|-----------|-----------|---------|---------|
| **Vote Service** | Python 3 + Flask | Latest | Frontend voting interface |
| **Result Service** | Node.js + Express | Latest | Results dashboard with WebSocket |
| **Worker Service** | .NET Core (C#) | Latest | Background vote processor |

### Infrastructure Layer

| Component | Technology | Version | Purpose |
|-----------|-----------|---------|---------|
| **Container Runtime** | Docker | 24.x | Application containerization |
| **Orchestration** | Kubernetes | 1.28+ | Container orchestration platform |
| **Package Manager** | Helm | 3.x | Database lifecycle management |
| **Message Queue** | Redis | 7-alpine | Vote queuing and caching |
| **Database** | PostgreSQL | 14-alpine | Persistent data storage |
| **Ingress Controller** | NGINX | Latest | Load balancing & external access |
| **Dev Cluster** | Minikube | Latest | Local Kubernetes environment |

### DevOps Toolchain

| Tool | Purpose |
|------|---------|
| **Docker Compose** | Local development orchestration |
| **kubectl** | Kubernetes CLI management |
| **Helm** | Package management for charts |
| **GitHub Actions** | CI/CD automation |
| **Trivy** | Container vulnerability scanning |
| **Bitnami Charts** | Production-ready database Helm charts |

---

## ✨ Key Features
### Technical Excellence

#### Security (Defense in Depth)
- ✅ **Pod Security Admission (PSA)** - Restricted level enforcement
- ✅ **Non-root containers** - All services run as unprivileged users
- ✅ **Dropped capabilities** - ALL Linux capabilities removed
- ✅ **Seccomp profiles** - Syscall filtering enabled (RuntimeDefault)
- ✅ **NetworkPolicies** - Zero-trust networking with default-deny
- ✅ **Vulnerability scanning** - Automated Trivy scans in CI/CD pipeline
- ✅ **Secrets management** - Kubernetes Secrets with base64 encoding
- ✅ **Security alerts** - SARIF reports uploaded to GitHub Security tab

#### Reliability & Resilience
- ✅ **Health probes** - Liveness and readiness checks for all services
- ✅ **Resource limits** - CPU and memory constraints prevent resource exhaustion
- ✅ **Persistent volumes** - StatefulSets with PersistentVolumeClaims
- ✅ **Graceful degradation** - Worker retries on connection failures
- ✅ **Service redundancy** - Multiple replicas for frontend services
- ✅ **Database persistence** - Data survives pod rescheduling


---

## 📁 Project Structure

```
voting-app/
├── README.md                          # This file - comprehensive project documentation
├── architecture.excalidraw.png        # Visual architecture diagram
├── docker-compose.yml                 # Local development orchestration
│
├── .github/
│   └── workflows/
│       └── ci-cd.yml                  # GitHub Actions CI/CD pipeline
│
├── vote/                              # Vote service (Python/Flask)
│   ├── Dockerfile                     # Multi-stage optimized build
│   ├── app.py                         # Flask application code
│   ├── requirements.txt               # Python dependencies
│   └── README.md                      # Service-specific documentation
│
├── result/                            # Result service (Node.js/Express)
│   ├── Dockerfile                     # Multi-stage Node.js build
│   ├── server.js                      # Express + WebSocket server
│   ├── package.json                   # Node.js dependencies
│   └── README.md                      # Service-specific documentation
│
├── worker/                            # Worker service (.NET Core)
│   ├── Dockerfile                     # .NET Core build
│   ├── Program.cs                     # Vote processing logic
│   ├── Worker.csproj                  # .NET project file
│   └── README.md                      # Service-specific documentation
│
├── healthchecks/                      # Custom health check scripts
│   ├── redis.sh                       # Redis connectivity validation
│   └── postgres.sh                    # PostgreSQL query execution test
│
├── k8s/                               # Kubernetes manifests
│   ├── README.md                      # Kubernetes deployment quick reference
│   │
│   ├── base/                          # Core application resources
│   │   ├── namespace.yml              # Namespace with PSA enforcement
│   │   ├── ingress.yml                # External access configuration
│   │   ├── configmaps/                # Non-sensitive configuration
│   │   ├── secrets/                   # Sensitive credentials
│   │   ├── vote/                      # Vote deployment & service
│   │   ├── result/                    # Result deployment & service
│   │   ├── worker/                    # Worker deployment
│   │   └── network-policies/          # Zero-trust network rules
│   │
│   ├── redis/                         # Redis StatefulSet (manual deployment)
│   │   ├── statefulset.yml
│   │   ├── service.yml
│   │   └── configmap.yml
│   │
│   └── postgres/                      # PostgreSQL StatefulSet (manual deployment)
│       ├── statefulset.yml
│       ├── service.yml
│       └── configmap.yml
│
├── helm-values/                       # Helm chart configurations
│   ├── redis-values.yaml              # Redis Helm customization
│   ├── postgres-values.yaml           # PostgreSQL Helm customization
│   └── service-alias.yaml             # DNS alias for Redis naming compatibility
│
├── seed-data/                         # Optional test data for development
```

---

## 🚀 Getting Started

### Prerequisites

Ensure you have the following tools installed:

```bash
# Required
docker version       # 24.x+
docker compose version
minikube version     # v1.30+
kubectl version      # v1.28+
helm version         # v3.12+

# Optional but recommended
trivy --version      # Security vulnerability scanner
```

### Quick Start (5 Minutes)

#### Option 1: Local Development with Docker Compose

```bash
# Clone repository
git clone https://github.com/esraashaabanelsayed/voting-app-devops-production.git
cd voting-app-devops-production

# Start all services
docker compose up -d

# Access application
# Vote:   http://localhost:8080
# Result: http://localhost:8081

# Stop services
docker compose down
```

#### Option 2: Kubernetes with Minikube (Automated)

```bash
# Start Minikube
minikube start 
# Enable required addons
minikube addons enable ingress


# Configure local DNS
echo "$(minikube ip) vote.com result.com" | sudo tee -a /etc/hosts

# Access application
open http://vote.com
open http://result.com
```
![alt text](<Screenshot from 2025-11-22 13-07-35.png>)
![alt text](<Screenshot from 2025-11-22 13-22-51.png>)
For detailed deployment instructions, see [k8s/README.md](k8s/README.md).

---

## 📦 Deployment Options

### 1. Docker Compose (Development)

**Best for:** Local development, rapid iteration, learning the application

**Features:**
- Two-tier networking for isolation
- Health checks with custom scripts
- Persistent volumes
- Automatic service dependency management

**Deployment time:** < 1 minute

See `docker-compose.yml` for configuration details.

---

### 2. Kubernetes with Manual StatefulSets


**Features:**
- Custom Kubernetes manifests
- Full control over configuration
- Simple service naming (redis, db)
- No Helm dependency

**Deployment:**
```bash
kubectl apply -f k8s/base/namespace.yml
kubectl apply -f k8s/base/configmaps/
kubectl apply -f k8s/base/secrets/
kubectl apply -f k8s/redis/
kubectl apply -f k8s/postgres/
kubectl apply -f k8s/base/vote/
kubectl apply -f k8s/base/result/
kubectl apply -f k8s/base/worker/
kubectl apply -f k8s/base/network-policies/
kubectl apply -f k8s/base/ingress.yml
```


---

### 3. Kubernetes with Helm Charts (Production)

**Best for:** Production deployments, automated lifecycle management

**Features:**
- Bitnami production-grade database charts
- Built-in upgrade and rollback capabilities
- Security best practices out-of-the-box
- Automated backup and monitoring integration
- Service alias for naming compatibility

**Deployment:**
```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm install postgres bitnami/postgresql -f helm-values/postgres-values.yaml -n voting-app
helm install redis bitnami/redis -f helm-values/redis-values.yaml -n voting-app
kubectl apply -f helm-values/service-alias.yaml
kubectl apply -f k8s/base/
```


**Note:** Helm Redis chart creates `redis-master` service. Service alias bridges naming gap. See [docs/HELM_MIGRATION.md](docs/HELM_MIGRATION.md).

---

### 4. CI/CD with GitHub Actions (Automated)

**Best for:** Production deployments, continuous delivery

**Features:**
- Automated builds on every push
- Security scanning with Trivy
- Automated deployment to Minikube
- Smoke tests for validation
- SARIF reports for security analysis

**Trigger:** Push to `main` branch or create pull request

**Pipeline stages:**
1. Build and push container images
2. Security scan with Trivy
3. Deploy to Minikube test environment
4. Run smoke tests
5. Publish results

See `.github/workflows/ci-cd.yml` for pipeline configuration.

---

## 🔄 CI/CD Pipeline

### Pipeline Architecture

The GitHub Actions pipeline implements a complete CI/CD workflow:

**Build Stage:**
- Matrix builds for vote, result, and worker services
- Multi-platform Docker builds with BuildKit
- Image tagging with commit SHA and latest
- Push to GitHub Container Registry (ghcr.io)
- Build caching for faster iterations

**Security Stage:**
- Trivy vulnerability scanning
- SARIF report generation
- Upload to GitHub Security tab
- Fail on CRITICAL/HIGH vulnerabilities

**Deploy Stage:**
- Minikube cluster provisioning
- Helm database deployment
- Application service deployment
- NetworkPolicy enforcement
- Health check verification

**Test Stage:**
- Smoke tests for vote and result services
- Connectivity validation
- Deployment status verification

### Security Scanning Results

Current known vulnerabilities (Trivy findings):

**Medium Severity:**
- BusyBox netstat vulnerability (CVE-2024-XXXXX) - Affects worker service
- Local network enumeration possible

**Low Severity:**
- BusyBox tar filename handling - Minimal risk

**Remediation:** These vulnerabilities exist in the base Alpine image. Consider:
1. Using distroless images for enhanced security
2. Updating to latest Alpine version when available
3. Implementing runtime security monitoring (Falco)

Security reports are automatically uploaded to GitHub Security tab for tracking.

---

## 🔒 Security Implementation

### Defense in Depth Strategy

Security is implemented at multiple layers:

**1. Container Security**
- Non-root users (UID 1000 for apps, 999 for databases)
- Read-only root filesystem where possible
- Dropped ALL Linux capabilities
- Seccomp profiles enabled (RuntimeDefault)
- No privilege escalation allowed

**2. Pod Security Standards**
- PSA enforced at namespace level (restricted)
- Strictest Kubernetes security policy
- Prevents common container escape techniques
- Audit and warn modes enabled

**3. NetworkPolicies Require Precision**
- Pod labels must exactly match NetworkPolicy selectors
- Helm charts use different labeling conventions
- DNS egress is critical for service discovery
- Test policies incrementally to avoid debugging nightmares
- Use `kubectl get pods --show-labels` religiously

**4. StatefulSets for State, Deployments for Stateless**
- StatefulSets provide stable network identity and storage
- Essential for databases requiring persistent data
- Deployments better for scalable, stateless services
- Choose based on workload characteristics, not preference

**5. PSA Restricted is Worth the Effort**
- Comprehensive security contexts required for every container
- UID/GID management is critical
- Some applications need modification to run non-root
- Security benefits far outweigh implementation complexity

**6. Security Scanning Reveals Hidden Issues**
- Base images contain vulnerabilities you didn't introduce
- Regular scanning catches supply chain issues
- Trivy integration in CI/CD provides continuous monitoring
- Vulnerability management is ongoing, not one-time
 
**7. Service Aliases Solve Integration Issues**
- ExternalName services provide DNS-level abstraction
- Bridge gaps between application expectations and infrastructure reality
- Temporary workaround or permanent solution depending on context
- Better than modifying application code in some scenarios


---




## 📊 Project Metrics

### Scale
- **Microservices:** 5 (vote, result, worker, redis, postgresql)
- **Kubernetes Resources:** 35+ manifests
- **Lines of Configuration:** ~2000 (YAML, scripts)
- **Docker Images:** 3 custom + 2 official
- **Container Registry:** GitHub Container Registry (ghcr.io)

### Security
- **NetworkPolicies:** 6 (default-deny + 5 service-specific)
- **Security Contexts:** 100% of pods (non-root, capabilities dropped)
- **Vulnerability Scans:** Automated on every build
- **PSA Level:** Restricted (strictest Kubernetes policy)

### Automation
- **CI/CD Pipeline:** GitHub Actions
- **Build Matrix:** 3 services in parallel
- **Automated Tests:** Smoke tests + health checks
- **Deployment Target:** Minikube (dev)

### Reliability
- **Service Replicas:** 2x vote, 2x result, 1x worker
- **Health Probes:** Liveness + readiness for all services
- **Persistent Storage:** StatefulSets with PVCs
- **Resource Limits:** CPU and memory constraints on all pods


---

<div align="center">

**Made with ❤️, ☸️, and 🐳**


---

**⭐ Star this repository if you found it helpful!**

**🔗 [View on GitHub](https://github.com/esraashaabanelsayed/voting-app-devops-production)**

---
