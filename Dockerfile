# Multi-stage Dockerfile for WebhookPulse
# Stage 1: Development
# Stage 2: Production build
# Stage 3: Production runtime (nginx)

# ==================== STAGE 1: Development ====================
FROM node:22-alpine AS development

WORKDIR /app

# Install dependencies for native modules
RUN apk add --no-cache git

# Copy package files
COPY package*.json ./
RUN npm ci

# Copy source code
COPY . .

# Expose Vite dev server port
EXPOSE 5173

CMD ["npm", "run", "dev"]

# ==================== STAGE 2: Build ====================
FROM node:22-alpine AS build

WORKDIR /app

# Install dependencies
COPY package*.json ./
RUN npm ci

# Copy source and build
COPY . .
RUN npm run build

# ==================== STAGE 3: Production ====================
FROM nginx:alpine AS production

# Copy built assets
COPY --from=build /app/dist /usr/share/nginx/html

# Copy nginx config
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Security headers
RUN echo 'server_tokens off;' > /etc/nginx/conf.d/security.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
