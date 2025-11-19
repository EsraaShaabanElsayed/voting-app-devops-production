FROM mcr.microsoft.com/dotnet/runtime:8.0-alpine AS base
WORKDIR /app
RUN adduser -u 1000 -D -s /bin/sh appuser

# Use .NET 8.0 Alpine SDK for building
FROM mcr.microsoft.com/dotnet/sdk:8.0-alpine AS build
WORKDIR /src

# Copy project file first to leverage Docker cache
COPY Worker.csproj .
RUN dotnet restore --runtime linux-musl-x64

# Copy source code
COPY . .
RUN dotnet publish \
    -c release \
    -o /app \
    -r linux-musl-x64 \
    --self-contained false \
    --no-restore \
    /p:DebugType=None \
    /p:DebugSymbols=false

# Final stage
FROM base AS final
WORKDIR /app

# Install minimal runtime dependencies only
RUN apk add --no-cache \
    libc6-compat \
    libgcc \
    libstdc++ \
    && rm -rf /var/cache/apk/*

# Copy the built application
COPY --from=build --chown=appuser:appuser /app .

# Security hardening
USER appuser

# Health check with appropriate intervals
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD ps aux | grep '[d]otnet Worker.dll' || exit 1

# Set secure environment variables
ENV DOTNET_RUNNING_IN_CONTAINER=true \
    DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=false \
    COMPlus_EnableDiagnostics=0

# Use non-root user
USER appuser

# Entry point
ENTRYPOINT ["dotnet", "Worker.dll"]