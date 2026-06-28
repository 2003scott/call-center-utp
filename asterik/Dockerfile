FROM node:18-alpine
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
# Usamos ts-node para correr TS directamente en desarrollo
CMD ["npx", "ts-node", "src/index.ts"]
EXPOSE 3000