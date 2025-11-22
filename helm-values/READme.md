# Migration from Manual StatefulSets to Helm Charts

## 📖 Overview

This document explains the migration from manually-managed Redis and PostgreSQL StatefulSets to Helm-managed deployments, including the service naming challenges encountered and how they were resolved.

---

## 🔄 What Changed

### Before: Manual StatefulSets

**Approach:** Custom YAML manifests for Redis and PostgreSQL
```
k8s/
├── redis/
│   ├── statefulset.yml      # Custom Redis StatefulSet
│   ├── service.yml           # Service named "redis"
│   └── configmap.yml         # Health check scripts
└── postgres/
    ├── statefulset.yml       # Custom PostgreSQL StatefulSet
    ├── service.yml            # Service named "db"
    └── configmap.yml          # Health check scripts
```

**Deployment:**
```bash
kubectl apply -f k8s/redis/
kubectl apply -f k8s/postgres/
```

**Service Names:**
- Redis: `redis`
- PostgreSQL: `db`

✅ **Advantages:**
- Full control over naming
- Matches application code expectations
- Simple to understand and modify

❌ **Disadvantages:**
- Manual lifecycle management
- No built-in upgrade/rollback
- Must manually manage persistence, backups, security

---

### After: Helm Charts

**Approach:** Using Bitnami Helm charts with custom values

```
helm-values/
├── redis-values.yaml         # Redis configuration
├── postgres-values.yaml      # PostgreSQL configuration
└── service-alias.yaml        # DNS alias for Redis
```

**Deployment:**
```bash
# Deploy databases via Helm
helm install redis bitnami/redis -f helm-values/redis-values.yaml -n voting-app
helm install postgres bitnami/postgresql -f helm-values/postgres-values.yaml -n voting-app

# Apply service alias (workaround for Redis naming)
kubectl apply -f helm-values/service-alias.yaml
```

**Service Names:**
- Redis: `redis-master` ⚠️ (changed)
- PostgreSQL: `db` ✅ (unchanged)

✅ **Advantages:**
- Production-grade charts maintained by Bitnami
- Built-in lifecycle management (upgrade/rollback)
- Better security defaults
- Persistence, backups, monitoring built-in
- Community support and updates

❌ **Disadvantages:**
- Less control over resource naming
- Service naming conflicts with application code

---

## ⚠️ The Service Naming Problem

### Root Cause

The application code has **hardcoded hostnames**:

**Worker Service (`worker/Program.cs`):**
```csharp
// Line 18-19
var pgsql = OpenDbConnection("Server=db;Username=postgres;Password=postgres;");
var redisConn = OpenRedisConnection("redis");

// Line 33
redisConn = OpenRedisConnection("redis");
```

**Result Service (`result/server.js`):**
```javascript
var pool = new Pool({
  connectionString: 'postgres://postgres:postgres@db/postgres'
});
```

**Key Issue:** Code expects services named `redis` and `db`, but Helm Redis chart creates `redis-master`.

---

## 🔍 Why Different Behavior?

### PostgreSQL Helm Chart ✅

```yaml
# helm-values/postgres-values.yaml
fullnameOverride: db
```

**Result:** Service created as `db`

The Bitnami PostgreSQL chart **respects `fullnameOverride`** for the primary service name.

**Services created:**
- `db` (primary service)
- `db-hl` (headless service)

✅ **Works perfectly** - matches application expectations!

---

### Redis Helm Chart ❌

```yaml
# helm-values/redis-values.yaml
fullnameOverride: redis
```

**Result:** Service created as `redis-master` (not `redis`)

The Bitnami Redis chart **appends `-master` suffix** even with `fullnameOverride`.

**Services created:**
- `redis-master` (master service)
- `redis-replicas` (replica service)
- `redis-headless` (headless service)

❌ **Problem:** Application expects `redis`, but service is `redis-master`

---

## 🛠️ The Solution: Service Alias

Since the Redis chart enforces the `-master` suffix and the application code is hardcoded, we created a **DNS alias** to bridge the gap.

### Service Alias Configuration

**File:** `helm-values/service-alias.yaml`

```yaml
apiVersion: v1
kind: Service
metadata:
  name: redis
  namespace: voting-app
spec:
  type: ExternalName
  externalName: redis-master.voting-app.svc.cluster.local
```

### How It Works

```
Application Code        DNS Resolution           Actual Service
─────────────────────────────────────────────────────────────────
redis                →  redis                →  redis-master
(hardcoded)             (alias service)         (Helm-created)
```

**Step-by-step:**
1. Application tries to connect to `redis`
2. Kubernetes DNS resolves `redis` service
3. ExternalName service redirects to `redis-master.voting-app.svc.cluster.local`
4. Connection established with Helm-managed Redis

### Deployment

```bash
# After deploying Redis via Helm
helm install redis bitnami/redis -f helm-values/redis-values.yaml -n voting-app

# Apply the service alias
kubectl apply -f helm-values/service-alias.yaml
```


### Complete Deployment Steps

```bash
# 1. Create namespace and base resources
kubectl apply -f k8s/base/namespace.yml
kubectl apply -f k8s/base/configmaps/
kubectl apply -f k8s/base/secrets/

# 2. Deploy PostgreSQL via Helm
helm install postgres bitnami/postgresql \
  -f helm-values/postgres-values.yaml \
  -n voting-app \
  --wait

# 3. Deploy Redis via Helm
helm install redis bitnami/redis \
  -f helm-values/redis-values.yaml \
  -n voting-app \
  --wait

# 4. Apply Redis service alias (CRITICAL!)
kubectl apply -f helm-values/service-alias.yaml


# 5. Deploy application services
kubectl apply -f k8s/base/vote/
kubectl apply -f k8s/base/result/
kubectl apply -f k8s/base/worker/

# 7. Apply network policies
kubectl apply -f k8s/base/network-policies/

# 8. Deploy ingress
kubectl apply -f k8s/base/ingress.yml
```

### Verification

```bash
# Check Helm releases
helm list -n voting-app

# Check services
kubectl get svc -n voting-app

# Should see:
# NAME             TYPE           CLUSTER-IP       PORT(S)
# redis            ExternalName   <none>           <none>        (alias)
# redis-master     ClusterIP      10.x.x.x         6379/TCP      (actual)
# db               ClusterIP      10.x.x.x         5432/TCP      (actual)

# Test DNS resolution from worker
kubectl exec -it <worker-pod> -n voting-app -- nslookup redis
# Should resolve to redis-master IP

# Check worker logs (should show successful connections)
kubectl logs -f deployment/worker -n voting-app
# Connected to db
# Found redis at 10.x.x.x
# Connecting to redis
```

---
