# Etapa 1: Build da aplicação (compilação do front-end)
FROM node:18-alpine AS build

# Define o diretório de trabalho dentro do container como /app
# Qualquer comando a partir daqui será executado dentro de /app
WORKDIR /app

# Copia apenas os arquivos de dependência para aproveitar cache de camadas
COPY package*.json ./

# Instala as dependências do projeto (npm install lê o package.json)
RUN npm install

# Copia todo o restante do código fonte para dentro do container
COPY . .

# Roda o comando de build da aplicação (gera a pasta /dist)
RUN npm run build


# Etapa 2: Servir a aplicação com Nginx (imagem final e mais leve)
FROM nginx:alpine

# Copia os arquivos estáticos gerados no build (/dist)
# para o diretório padrão do Nginx que serve arquivos HTML
COPY --from=build /app/dist /usr/share/nginx/html

# Expõe a porta 80, que é a porta padrão HTTP do Nginx
EXPOSE 80