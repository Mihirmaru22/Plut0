FROM node:20-alpine

WORKDIR /app

COPY package.json ./
RUN npm install

COPY server.ts ./
COPY tsconfig.json* ./

RUN npx tsc server.ts --outDir dist --target ES2022 --module CommonJS || true

EXPOSE 8787

CMD ["node", "dist/server.js"]
