FROM python:3.10.12-slim-bullseye AS base

WORKDIR /app

COPY requirements.txt ./

RUN pip install   --no-cache-dir -r requirements.txt


FROM python:3.10.12-slim-bullseye AS final


LABEL maintainer="esraashaaban114@gmail.com"
LABEL org.opencontainers.image.source="https://github.com/esraa/voting-app"
LABEL org.opencontainers.image.version="1.2.3"
LABEL security.compliance="pci-dss,soc2"


# Create a non-root user and switch to it
RUN useradd -r -m -s /sbin/nologin  -u 1000 voteuser

WORKDIR /app

# Copy installed packages from base stage (system-wide locations)
COPY --from=base /usr/local/lib/python3.10/site-packages/ /usr/local/lib/python3.10/site-packages/
COPY --from=base /usr/local/bin/ /usr/local/bin/


# Copy application code and set ownership to non-root user
COPY --chown=voteuser:voteuser . .


# Security: Make application directory read-only
RUN chmod -R 555 /app



# Switch to non-root user (required for Pod Security Admission)
USER voteuser




# Healthcheck to ensure the container is healthy
HEALTHCHECK --interval=30s --timeout=10s --retries=3 CMD curl --fail http://localhost:8080/ || exit 1

EXPOSE 8080

# Define our command to be run when launching the container
CMD ["gunicorn", "app:app", "-b", "0.0.0.0:8080", "--log-file", "-", "--access-logfile", "-", "--workers", "4", "--keep-alive", "0"]