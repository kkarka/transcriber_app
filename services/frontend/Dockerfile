# ---------- Build Stage ----------
FROM node:18-alpine AS builder

WORKDIR /app

COPY package*.json ./
# Use ci for faster, cleaner, deterministic builds in automated pipelines
RUN npm ci 

COPY . .
RUN npm run build

# ---------- Runtime Stage ----------
# Use the official unprivileged image. It runs as user 'nginx' (UID 101) by default.
FROM nginxinc/nginx-unprivileged:alpine


COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copy the built React/Vue app
COPY --from=builder /app/dist /usr/share/nginx/html

EXPOSE 8080

CMD ["nginx", "-g", "daemon off;"]