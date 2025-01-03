# Stage 1: Build
FROM node:20-alpine AS builder

# Create app directory
WORKDIR /usr/src/app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci --only=production

# Stage 2: Production
FROM node:20-alpine

# Create non-root user
RUN addgroup -S nodeuser && adduser -S -G nodeuser nodeuser

# Set working directory
WORKDIR /usr/src/app

# Copy from builder
COPY --from=builder /usr/src/app/node_modules ./node_modules
COPY app.js ./
COPY views ./views
COPY package*.json ./

# Set correct permissions
RUN chown -R nodeuser:nodeuser /usr/src/app

# Switch to non-root user
USER nodeuser

# Expose port
EXPOSE 8080

# Set production environment
ENV NODE_ENV=production

# Health check
HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 \
  CMD wget --spider http://localhost:8080 || exit 1

# Run the app
CMD ["node", "app.js"]