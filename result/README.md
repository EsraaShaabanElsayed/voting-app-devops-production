Here's the updated documentation reflecting the correct sequence of events:

```markdown
# Result Service - PostgreSQL Healthcheck & Security Implementation

## Service Overview
**Service Name**: `result`  
**Purpose**: Displays voting results from PostgreSQL database  
**Technology**: Node.js 22 (Alpine)
**Port**: 8081  
**Dependencies**: PostgreSQL database

---

## What Was Implemented

### 1. PostgreSQL Database Configuration & Healthcheck
### 2. Node.js Security Vulnerability Remediation (Package Updates)
### 3. Multi-Stage Docker Build Optimization (npm Removal)

---

## PostgreSQL Healthcheck Script

### Original Script (Provided - Bash)
```bash
#!/bin/bash
set -eo pipefail

host="$(hostname -i || echo '127.0.0.1')"
user="${POSTGRES_USER:-postgres}"
db="${POSTGRES_DB:-$POSTGRES_USER}"
export PGPASSWORD="${POSTGRES_PASSWORD:-}"

args=(
	# force postgres to not use the local unix socket (test "external" connectibility)
	--host "$host"
	--username "$user"
	--dbname "$db"
	--quiet --no-align --tuples-only
)

if select="$(echo 'SELECT 1' | psql "${args[@]}")" && [ "$select" = '1' ]; then
	exit 0
fi

exit 1
```

### Modified Script (POSIX Shell Compatible)
**File**: `./healthchecks/postgres.sh`

```bash
#!/bin/sh
set -eo pipefail

host="$(hostname -i || echo '127.0.0.1')"
user="${POSTGRES_USER:-postgres}"
db="${POSTGRES_DB:-postgres}"
export PGPASSWORD="${POSTGRES_PASSWORD:-postgres}"

# Direct command instead of array syntax
if select="$(echo 'SELECT 1' | psql --host "$host" --username "$user" --dbname "$db" --quiet --no-align --tuples-only)" && [ "$select" = '1' ]; then
	exit 0
fi

exit 1
```

---

## Issues Resolved

### Issue 1: Shell Compatibility Error

**Error Message**:
```
/healthchecks/postgres.sh: line 10: syntax error: unexpected "("
```

**Root Cause**:
- Original script uses bash array syntax: `args=(...)`
- Alpine Linux uses `sh` (POSIX shell), not bash
- POSIX shell doesn't support bash arrays

**Solution Applied**:
1. Removed array syntax
2. Converted to inline arguments:
   ```bash
   # Before:
   args=(--host "$host" --username "$user")
   psql "${args[@]}"
   
   # After:
   psql --host "$host" --username "$user" --dbname "$db" --quiet --no-align --tuples-only
   ```

**Justification**:
- Adapting provided scripts to container environment is standard practice
- Maintains original functionality and logic
- Avoids adding unnecessary dependencies (bash package) to Alpine container
- Script still performs same validation: connects to PostgreSQL and executes `SELECT 1`

---

### Issue 2: Password Authentication Failure

**Error Message**:
```
psql: error: connection to server at "172.18.0.2", port 5432 failed: 
FATAL: password authentication failed for user "postgres"
```

**Root Cause**:
- Stale PostgreSQL data in Docker volume from previous runs
- PostgreSQL sets credentials during first initialization
- Existing volume data retains old credentials, ignoring new environment variables

**Debugging Steps**:
1. Verified environment variables inside container:
   ```bash
   docker exec postgres env | grep POSTGRES
   # Confirmed: POSTGRES_PASSWORD=postgres was set
   ```

2. Tested healthcheck script manually:
   ```bash
   docker exec postgres sh /healthchecks/postgres.sh
   # Result: Authentication failed
   ```

**Solution Applied**:
1. Removed stale volumes:
   ```bash
   docker compose down -v
   ```

2. Added default values in script for robustness:
   ```bash
   export PGPASSWORD="${POSTGRES_PASSWORD:-postgres}"
   db="${POSTGRES_DB:-postgres}"
   ```

3. Restarted with fresh volumes:
   ```bash
   docker compose up -d
   ```

**Result**: PostgreSQL initialized with correct credentials, healthcheck passed.

---

### Issue 3: High-Severity Node.js Security Vulnerabilities 🔒

**Initial Security Scan Results**:
```
Total Vulnerabilities: 23
- Critical: 1
- High: 10
- Medium/Low: 12
```

**Major Vulnerabilities Identified**:

| Package | Vulnerable Version | CVE | Severity | Issue |
|---------|-------------------|-----|----------|-------|
| `ws` | 8.11.0 | CVE-2024-37890 | HIGH | Denial of Service |
| `express` | 4.18.2 | Multiple CVEs | HIGH | Prototype Pollution, ReDoS |
| `cookie` | 0.4.1/0.5.0 | CVE-2024-47764 | HIGH | Out-of-bounds Read |
| `glob` | 10.4.5 | CVE-2025-64756 | HIGH | Command injection via CLI (transitive) |

---

## Solution Phase 1: Dependency Updates (Resolved Most Vulnerabilities)

### Root Cause: Outdated Dependencies

The majority of vulnerabilities stemmed from outdated direct dependencies in `package.json`. These required updating the lockfile to pull in secure versions.

### Steps Taken

**Step 1: Added Package Overrides**

Added to `package.json` to ensure secure versions:
```json
{
  "overrides": {
    "ws": "^8.17.1",
    "cookie": "^0.7.0"
  }
}
```

**Step 2: Forced Clean Lockfile Regeneration**

```bash
# Delete old lockfile and regenerate with overrides applied
docker run --rm -v "$PWD":/usr/src/app -w /usr/src/app node:22-alpine \
    sh -c "rm -f package-lock.json && npm install"
```

**Why This Worked**:
- Deleting `package-lock.json` forced npm to re-resolve the entire dependency tree
- The `npm install` command (not `ci`) reads `package.json` and honors the `overrides` section
- Generated a new lockfile with secure transitive dependencies

**Step 3: Updated Direct Dependencies**

```bash
# Updated packages to latest secure versions
npm install express@4.21.2
npm install socket.io@4.8.1
npm install cookie-parser@1.4.7
```

### Result After Phase 1

**Security Scan Output**:
```
Node.js (node-pkg)
Total: 1 (HIGH: 1)
┌─────────────────────┬────────────────┬──────────┬───────────────────┬────────────────┐
│       Library       │ Vulnerability  │ Severity │ Installed Version │ Fixed Version  │
├─────────────────────┼────────────────┼──────────┼───────────────────┼────────────────┤
│ glob (package.json) │ CVE-2025-64756 │ HIGH     │ 10.4.5            │ 11.1.0, 10.5.0 │
└─────────────────────┴────────────────┴──────────┴───────────────────┴────────────────┘
```

**Achievement**: Reduced from **23 vulnerabilities to 1 vulnerability** by updating packages.

---

## Solution Phase 2: Multi-Stage Build (Eliminated Remaining Vulnerability)

### The Remaining Problem: glob via npm

**Issue Analysis**:
- `glob` package is **not** in our application dependencies
- It's a transitive dependency of **npm itself**
- Updating application packages cannot fix this
- `glob` only affects npm's CLI operations, not our application runtime

### Solution: Remove npm from Production Image

Since npm is only needed during the build phase and not at runtime, we implemented a multi-stage build to eliminate it entirely from the final image.

#### Final Dockerfile with Multi-Stage Build

```dockerfile
# ------------------------------------
# Stage 1: Builder - Install Dependencies
# ------------------------------------
FROM node:22-alpine AS builder

WORKDIR /usr/src/app

# Copy package files
COPY package*.json ./

# Install dependencies (npm is needed here)
RUN npm ci --production && \
    npm cache clean --force

# ------------------------------------------
# Stage 2: Production - Minimal Runtime
# ------------------------------------------
FROM node:22-alpine

WORKDIR /usr/src/app

# Install only runtime essentials
RUN apk update && apk upgrade --no-cache && \
    apk add --no-cache curl && \
    # Remove npm completely from production image
    rm -rf /usr/local/lib/node_modules/npm \
           /usr/local/bin/npm \
           /usr/local/bin/npx \
           /opt/yarn* \
           ~/.npm

# Copy only node_modules from builder (not npm)
COPY --from=builder /usr/src/app/node_modules ./node_modules

# Copy application source
COPY . .

LABEL maintainer="esraashaaban114@gmail.com"
LABEL org.opencontainers.image.source="https://github.com/EsraaShaabanElsayed/voting-app-devops-production.git"

# Security: Run as non-root user
RUN adduser -D resultsuser && \
    chown -R resultsuser:resultsuser /usr/src/app

USER resultsuser

EXPOSE 8081
ENV PORT=8081

# Healthcheck for orchestration readiness
HEALTHCHECK --interval=30s --start-period=30s --timeout=10s --retries=3 \
    CMD curl --fail http://localhost:8081/ || exit 1

CMD [ "node", "server.js" ]
```

**Key Security Features**:
1. **Multi-stage build**: Separates build dependencies from runtime
2. **npm removal**: Eliminates npm/npx from final image (removes glob vulnerability)
3. **Non-root user**: Application runs as unprivileged `resultsuser`
4. **Minimal runtime**: Only Node.js and curl in production image
5. **Latest Alpine**: Uses `node:22-alpine` with security updates

**Why This Eliminates the Vulnerability**:
- Builder stage uses npm to install dependencies
- Production stage copies only `node_modules` folder
- npm (and its dependency `glob`) is completely absent from final image
- No npm = no glob = no CVE-2025-64756

---

## Final Security Scan Result ✅

```bash
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
    aquasec/trivy image result:test
```
![alt text](<Screenshot from 2025-11-19 12-07-42-2.png>)
**Result**:
```
Report Summary
┌────────────────────────────────────┬──────────┬─────────────────┬─────────┐
│              Target                │   Type   │ Vulnerabilities │ Secrets │
├────────────────────────────────────┼──────────┼─────────────────┼─────────┤
│ result:test (alpine 3.22.2)        │  alpine  │        0        │    -    │
│ usr/src/app/package.json           │ node-pkg │        0        │    -    │
└────────────────────────────────────┴──────────┴─────────────────┴─────────┘

Legend: '-' = Not scanned | '0' = Clean (no security findings detected)
```

**Achievement**: **0 vulnerabilities** across all 100+ npm packages and OS packages.

---

## Summary: Two-Phase Vulnerability Resolution

| Phase | Action | Vulnerabilities Removed | Method |
|-------|--------|------------------------|--------|
| **Phase 1** | Update Dependencies | 22 vulnerabilities | Regenerated `package-lock.json` with secure versions |
| **Phase 2** | Remove npm from Runtime | 1 vulnerability (glob) | Multi-stage Docker build |
| **Result** | Complete Security | ✅ 0 vulnerabilities | Combined approach |

### Key Insight: Different Problems, Different Solutions

1. **Application Dependencies** (ws, express, cookie):
   - Fixed by updating `package.json` and regenerating lockfile
   - Required using `npm install` instead of `npm ci`

2. **Build Tool Dependencies** (glob via npm):
   - Cannot be fixed by package updates (not our dependency)
   - Fixed by removing npm from production image
   - Required multi-stage Docker build

---

## Key Takeaways: npm ci vs npm install

Understanding when to use each command is critical for secure builds:

| Feature | `npm ci` | `npm install` |
|---------|----------|---------------|
| **Purpose** | Clean, reproducible installs (CI/CD) | Dependency resolution and updates |
| **Lockfile** | Strictly follows it | Creates/updates it |
| **Overrides** | Ignores if lockfile conflicts | Honors and applies them |
| **Speed** | Very fast | Slower (full resolution) |
| **Use Case** | Production builds with known-good lockfile | Fixing dependency conflicts |

---

## Verification & Testing

### 1. Check PostgreSQL Health
```bash
docker ps
# STATUS should show: Up X minutes (healthy)
```

### 2. Test Healthcheck Manually
```bash
# Test script execution
docker exec postgres sh /healthchecks/postgres.sh
echo $?
# Expected: 0 (success)
```

### 3. Verify Result Service Connection
```bash
# Check result service logs
docker logs result

# Test result endpoint
curl http://localhost:8081
```

### 4. Security Scan Verification
```bash
# Run Trivy security scan
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
    aquasec/trivy image result:test

# Expected: "Clean (no security findings detected)"
```

---

## Commands Used

### Initial Setup
```bash
# Make healthcheck script executable
chmod +x ./healthchecks/postgres.sh
```

### Phase 1: Dependency Updates
```bash
# Regenerate lockfile with secure versions
docker run --rm -v "$PWD":/usr/src/app -w /usr/src/app node:22-alpine \
    sh -c "rm -f package-lock.json && npm install"

# Update direct dependencies
npm install express@4.21.2 socket.io@4.8.1 cookie-parser@1.4.7
```

### Phase 2: Build and Scan
```bash
# Build the multi-stage secure image
docker build -t result:test .

# Run security scan
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
    aquasec/trivy image result:test
```
![alt text](<Screenshot from 2025-11-19 12-07-42-1.png>)
### Clean Start
```bash
# Remove all containers and volumes
docker compose down -v

# Start services
docker compose up -d
```