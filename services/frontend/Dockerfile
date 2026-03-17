# ---------- Build Stage ----------
FROM node:18 AS builder

WORKDIR /app

COPY package*.json ./

RUN npm install

COPY . .

RUN npm run build


# ---------- Runtime Stage ----------
FROM nginx:alpine

# RUN addgroup -S appgroup && adduser -S appuser -G appgroup

COPY --from=builder /app/dist /usr/share/nginx/html

# RUN chown -R appuser:appgroup /usr/share/nginx/html

# USER appuser

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]