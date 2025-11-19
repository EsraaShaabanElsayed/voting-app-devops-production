FROM node:14-alpine AS base

# Update and upgrade Alpine packages
RUN apk update && apk upgrade --no-cache && \
     apk add --no-cache curl


# Create app directory
WORKDIR /usr/src/app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci --production && \
    npm cache clean --force



# Copy app source
COPY . .


LABEL maintainer="esraashaaban114@gmail.com"
LABEL org.opencontainers.image.source="https://github.com/EsraaShaabanElsayed/voting-app-devops-production.git"





# Create non-root user (after copying files to maintain ownership)
RUN adduser -D resultsuser && \
    chown -R resultsuser:resultsuser /usr/src/app
# Switch to non-root user
USER resultsuser

# Expose port
EXPOSE 8081
ENV PORT=8081

# Healthcheck
HEALTHCHECK --interval=30s --start-period=30s --timeout=10s --retries=3 \
    CMD curl --fail http://localhost:8081/ || exit 1


# Start the application
CMD [ "node", "server.js" ]