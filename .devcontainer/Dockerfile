FROM node:22-slim

# Instalace základních nástrojů
RUN apt-get update && apt-get install -y git procps && rm -rf /var/lib/apt/lists/*

# Vytvoření workspace s správnými oprávněními pro node uživatele
RUN mkdir -p /workspace /workspace/node_modules && chown -R node:node /workspace

# Nastavení pracovního adresáře
WORKDIR /workspace

# Instalace NestJS CLI globálně jako node uživatel
RUN npm install -g @nestjs/cli