FROM node:24-alpine AS builder
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --ignore-scripts
COPY . .
ENV VITE_HIDE_CHARTDB_CLOUD=true VITE_DISABLE_ANALYTICS=true VITE_APP_URL=/database-editor
RUN NODE_OPTIONS=--max-old-space-size=4096 npm run build

FROM nginx:stable-alpine
COPY --from=builder /app/dist /usr/share/nginx/html/database-editor
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
