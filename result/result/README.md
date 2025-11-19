# Result Service - PostgreSQL Healthcheck Implementation

## Service Overview
**Service Name**: `result`  
**Purpose**: Displays voting results from PostgreSQL database  
**Technology**: Node.js 14 (Alpine)  
**Port**: 8081  
**Dependencies**: PostgreSQL database

---

## What Was Implemented

### 1. PostgreSQL Database Configuration


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

**Security Features**:
- Non-root user (`resultsuser`)
- Minimal Alpine base image
- Application-level healthcheck via curl
- Security updates applied

---


## Verification & Testing

### 1. Check PostgreSQL Health
```bash
docker ps
# STATUS should show: Up X minutes (healthy)
```
![alt text](<Screenshot from 2025-11-19 09-01-02.png>)
### 2. Test Healthcheck Manually
```bash
# Test script execution
docker exec postgres sh /healthchecks/postgres.sh
echo $?
# Expected: 0 (success)
```
![alt text](<Screenshot from 2025-11-19 09-00-15.png>)
### 3. Verify Result Service Connection
```bash
# Check result service logs
docker logs result_container

# Test result endpoint
curl http://localhost:8081
```
![alt text](<Screenshot from 2025-11-19 08-59-16.png>)
### 4. Check Database Connectivity
```bash
# Connect to database from result container
docker exec result_container env | grep POSTGRES
```

---

## Commands Used

### Initial Setup
```bash
# Make healthcheck script executable
chmod +x ./healthchecks/postgres.sh
```

### Clean Start
```bash
# Remove all containers and volumes
docker compose down -v

# Start services
docker compose up -d
```

---
