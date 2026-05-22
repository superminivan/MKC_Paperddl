FROM node:22-alpine

WORKDIR /app
ENV NODE_ENV=production

# Install workspace deps (server depends on the root package via `file:..`)
COPY package.json package-lock.json ./
COPY server/package.json server/package.json
COPY web/package.json web/package.json
RUN npm ci --omit=dev

COPY server server
COPY conference conference

EXPOSE 5000
CMD ["node", "server/src/index.js"]
