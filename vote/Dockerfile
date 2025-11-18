FROM python:3.12-alpine AS base

# Update and upgrade Alpine packages
RUN apk update && apk upgrade --no-cache && \
     pip3 install --upgrade pip==25.3


WORKDIR /app

COPY requirements.txt ./

RUN pip install --no-cache-dir -r requirements.txt && \
    rm -rf /root/.cache/pip

FROM python:3.12-alpine AS final

# Update all packages to latest versions
RUN apk update && apk upgrade --no-cache && \
    pip3 install --upgrade pip==25.3 && \
    # Install only essential packages
    apk add --no-cache curl

LABEL maintainer="esraashaaban114@gmail.com"
LABEL org.opencontainers.image.source="https://github.com/EsraaShaabanElsayed/voting-app-devops-production.git"
LABEL security.compliance="pci-dss,soc2"

# Create a non-root user
RUN adduser -D -u 1000 voteuser

WORKDIR /app

# Copy installed packages from base stage
COPY --from=base /usr/local/lib/python3.12/site-packages/ /usr/local/lib/python3.12/site-packages/
COPY --from=base /usr/local/bin/ /usr/local/bin/

# Copy application code
COPY --chown=voteuser:voteuser . .

# Security: Make application directory read-only
RUN chmod -R 555 /app

# Switch to non-root user
USER voteuser

# Healthcheck
HEALTHCHECK --interval=30s --start-period=5s --timeout=10s --retries=3 \
    CMD curl --fail http://localhost:8080/ || exit 1

EXPOSE 8080

CMD ["gunicorn", "app:app", "-b", "0.0.0.0:8080", "--log-file", "-", "--access-logfile", "-", "--workers", "4", "--keep-alive", "0"]