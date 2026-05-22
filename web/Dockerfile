FROM node:22-alpine AS build

WORKDIR /app

# Install workspace deps (web depends on the root package via `file:..`)
COPY package.json package-lock.json ./
COPY web/package.json web/package.json
COPY server/package.json server/package.json
RUN npm ci

COPY web web
RUN npm run --prefix web build

FROM nginx:1.27-alpine

COPY web/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/web/dist /usr/share/nginx/html

EXPOSE 80
