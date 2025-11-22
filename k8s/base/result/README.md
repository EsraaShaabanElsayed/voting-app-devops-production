# Result Service Documentation

## Overview

The **Result Service** is a real-time web application that displays voting results using Socket.io for live updates. It shows the percentage of votes for "Cats vs Dogs" and updates dynamically as new votes come in.

## Architecture

- **Application**: Node.js with Socket.io (WebSocket-based real-time updates)
- **Container Port**: 8081
- **Service Port**: 80
- **Replicas**: 1-2 (requires session affinity for multiple replicas)
- **Dependencies**: PostgreSQL database

## Components

### 1. Deployment (`result-deployment.yaml`)

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: result
  namespace: voting-app
  labels:
    app: result
    tier: frontend
spec:
  replicas: 2  # Can scale with session affinity enabled
  selector:
    matchLabels:
      app: result
  template:
    metadata:
      labels:
        app: result
        tier: frontend
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        fsGroup: 1000
        seccompProfile:
          type: RuntimeDefault
      containers:
        - name: result
          image: esraa114/result:latest
          imagePullPolicy: Always
          ports:
            - containerPort: 8081
              name: http
              protocol: TCP
          envFrom:
            - configMapRef:
                name: result-config
            - secretRef:
                name: db-credentials
          resources:
            requests:
              memory: 128Mi
              cpu: 100m
            limits:
              memory: 256Mi
              cpu: 200m
          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: false
            runAsNonRoot: true
            runAsUser: 1000
            capabilities:
              drop:
                - ALL
          livenessProbe:
            httpGet:
              path: /
              port: 8081
            initialDelaySeconds: 15
            periodSeconds: 20
            timeoutSeconds: 5
            failureThreshold: 3
          readinessProbe:
            httpGet:
              path: /
              port: 8081
            initialDelaySeconds: 10
            periodSeconds: 10
            timeoutSeconds: 5
            failureThreshold: 3
```

### 2. Service (`result-service.yaml`)

```yaml
apiVersion: v1
kind: Service
metadata:
  name: result
  namespace: voting-app
  labels:
    app: result
spec:
  type: ClusterIP
  sessionAffinity: ClientIP  # Required for WebSocket stability
  sessionAffinityConfig:
    clientIP:
      timeoutSeconds: 10800  # 3 hours
  ports:
    - port: 80
      targetPort: 8081
      protocol: TCP
      name: http
  selector:
    app: result
```

**Important**: `sessionAffinity: ClientIP` is **required** when running multiple replicas to ensure WebSocket connections remain stable.

### 3. NetworkPolicy (`result-networkpolicy.yaml`)

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: result-netpol
  namespace: voting-app
spec:
  podSelector:
    matchLabels:
      app: result
  policyTypes:
  - Ingress
  - Egress
  ingress:
    # Allow ingress-nginx to access result pods
    - from:
      - namespaceSelector:
          matchLabels:
            app.kubernetes.io/name: ingress-nginx
      ports:
      - protocol: TCP
        port: 8081
  egress:
    # Allow connection to PostgreSQL
    - to:
        - podSelector:
            matchLabels:
              app: postgres
      ports:
        - protocol: TCP
          port: 5432
    
    # Allow DNS resolution
    - to:
      - namespaceSelector: {}
        podSelector:
          matchLabels:
            k8s-app: kube-dns
      ports:
      - protocol: UDP
        port: 53
      - protocol: TCP
        port: 53
```

### 4. Ingress Configuration

The result service is exposed via Ingress at `result.com`:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: voting-app-ingress
  namespace: voting-app
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
    nginx.ingress.kubernetes.io/ssl-redirect: "false"
    nginx.ingress.kubernetes.io/affinity: "cookie"
    nginx.ingress.kubernetes.io/session-cookie-name: "route"
    nginx.ingress.kubernetes.io/websocket-services: "result"
    nginx.ingress.kubernetes.io/proxy-read-timeout: "3600"
    nginx.ingress.kubernetes.io/proxy-send-timeout: "3600"
spec:
  ingressClassName: nginx
  rules:
  - host: result.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: result
            port:
              number: 80
```

**Critical Annotations**:
- `affinity: "cookie"` - Enables sticky sessions for WebSocket stability
- `websocket-services: "result"` - Enables WebSocket protocol upgrades
- `proxy-read-timeout` & `proxy-send-timeout` - Prevents WebSocket timeout

## Deployment Instructions

### Prerequisites

1. Kubernetes cluster with NGINX Ingress Controller installed
2. `voting-app` namespace created
3. PostgreSQL database deployed and accessible
4. ConfigMap `result-config` and Secret `db-credentials` created

### Deploy the Service

```bash
# Apply all manifests
kubectl apply -f result/deployment.yaml
kubectl apply -f result/service.yaml
kubectl apply -f network-policies/resultnetpol.yaml
kubectl apply -f ingress.yaml

# Verify deployment
kubectl get pods -n voting-app -l app=result
kubectl get svc -n voting-app result
kubectl get ingress -n voting-app
```


 **Access the application**:
```
http://result.com
```
![alt text](<Screenshot from 2025-11-22 10-32-35.png>)

## Troubleshooting

### Issue: White Page or "No votes yet" Display

**Symptoms**: Page loads as blank white screen or shows "No votes yet" even after voting.

**Causes**:
1. WebSocket connection failing
2. Load balancing across multiple pods without session affinity
3. PostgreSQL connection issues

**Solutions**:

1. **Check pod logs**:
```bash
kubectl logs -n voting-app -l app=result --tail=50
```

2. **Verify WebSocket connections in browser**:
   - Open DevTools (F12) → Network tab
   - Look for WebSocket upgrade requests
   - Check for 400/502 errors on `/socket.io/` endpoints

3. **Test service connectivity**:
```bash
# Port-forward to test directly
kubectl port-forward -n voting-app svc/result 8081:80

# Access at http://localhost:8081
```

4. **Temporarily reduce to 1 replica** (for testing):
```bash
kubectl scale deployment result -n voting-app --replicas=1
```

### Issue: NetworkPolicy Blocking Traffic

**Symptoms**: Service works with port-forward but not via Ingress.

**Solution**: Verify the namespace selector matches your ingress-nginx namespace labels:

```bash
# Check ingress-nginx namespace labels
kubectl get namespace ingress-nginx --show-labels

# Update NetworkPolicy to match the labels
# Common labels: app.kubernetes.io/name=ingress-nginx
```

### Issue: 400 Bad Request on Socket.io

**Symptoms**: Console shows repeated Socket.io 400 errors.

**Root Cause**: Multiple replicas without session affinity cause requests to be routed to different pods, invalidating Socket.io sessions.

**Solution**: Ensure both Service-level and Ingress-level session affinity are configured (see configurations above).

## Scaling Considerations

### Single Replica (Simple but No HA)
```bash
kubectl scale deployment result -n voting-app --replicas=1
```
- ✅ Simple, no session affinity needed
- ❌ No high availability
- ❌ Single point of failure

### Multiple Replicas (Production Setup)
```bash
kubectl scale deployment result -n voting-app --replicas=2
```
- ✅ High availability
- ✅ Load distribution
- ⚠️ **Requires** session affinity on both Service and Ingress
- ⚠️ Ensure all annotations are properly configured

## Environment Variables

Required environment variables (from ConfigMap and Secret):

**ConfigMap: `result-config`**
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: result-config
  namespace: voting-app
data:
  # Add your configuration here
  # Example: DATABASE_HOST: "postgres"
```

**Secret: `db-credentials`**
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: db-credentials
  namespace: voting-app
type: Opaque
data:
  # Base64 encoded values
  # POSTGRES_USER: <base64>
  # POSTGRES_PASSWORD: <base64>
```

## Security Features

- **Non-root container**: Runs as user 1000
- **Read-only root filesystem**: Disabled for application requirements
- **Dropped capabilities**: All capabilities dropped
- **No privilege escalation**: Explicitly disabled
- **Seccomp profile**: RuntimeDefault applied
- **Network policies**: Restricts traffic to only required services

## Monitoring

### Health Checks

- **Liveness Probe**: HTTP GET on `/` port 8081
  - Initial delay: 15s
  - Period: 20s
  - Timeout: 5s
  - Failure threshold: 3

- **Readiness Probe**: HTTP GET on `/` port 8081
  - Initial delay: 10s
  - Period: 10s
  - Timeout: 5s
  - Failure threshold: 3

### View Logs
```bash
# Recent logs
kubectl logs -n voting-app -l app=result --tail=100

# Follow logs
kubectl logs -n voting-app -l app=result -f

# Logs from specific pod
kubectl logs -n voting-app <pod-name>
```

## Resource Requirements

- **Requests**: 128Mi memory, 100m CPU
- **Limits**: 256Mi memory, 200m CPU

## Dependencies

- **PostgreSQL**: Required for storing and retrieving vote data
- **Ingress Controller**: NGINX Ingress Controller for external access
- **DNS**: Requires kube-dns/CoreDNS for service discovery

## Quick Reference Commands

```bash
# Deploy
kubectl apply -f result-deployment.yaml -f result-service.yaml -f result-networkpolicy.yaml

# Check status
kubectl get all -n voting-app -l app=result

# View logs
kubectl logs -n voting-app -l app=result --tail=50

# Scale
kubectl scale deployment result -n voting-app --replicas=2

# Debug
kubectl describe pod -n voting-app -l app=result
kubectl get endpoints -n voting-app result

# Port forward for testing
kubectl port-forward -n voting-app svc/result 8081:80

# Restart deployment
kubectl rollout restart deployment result -n voting-app

# Delete
kubectl delete deployment result -n voting-app
kubectl delete service result -n voting-app
kubectl delete networkpolicy result-netpol -n voting-app
```

## Known Issues & Solutions

| Issue | Cause | Solution |
|-------|-------|----------|
| White page on refresh | Multiple replicas without session affinity | Add `sessionAffinity: ClientIP` to Service and cookie affinity to Ingress |
| WebSocket 400 errors | Session ID mismatch across pods | Enable sticky sessions via Ingress annotations |
| Cannot access via domain | DNS not configured | Add domain to `/etc/hosts` pointing to 127.0.0.1 |
| NetworkPolicy blocking | Wrong namespace selector | Update to match actual ingress-nginx labels |
| Pod crashes | Resource limits too low | Increase memory/CPU limits |


## Version Information

- **Image**: `esraa114/result:latest`
- **Kubernetes API**: `apps/v1`, `v1`, `networking.k8s.io/v1`
- **Node.js Version**: (Check container image)
- **Socket.io Version**: (Check package.json in image)

-