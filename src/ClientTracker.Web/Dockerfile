FROM node:24-alpine AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY . .

ARG VITE_API_BASE_URL
ARG VITE_AZURE_CLIENT_ID
ARG VITE_AZURE_TENANT_ID
ARG VITE_API_SCOPE
ENV VITE_API_BASE_URL=$VITE_API_BASE_URL \
    VITE_AZURE_CLIENT_ID=$VITE_AZURE_CLIENT_ID \
    VITE_AZURE_TENANT_ID=$VITE_AZURE_TENANT_ID \
    VITE_API_SCOPE=$VITE_API_SCOPE

RUN npm run build

FROM nginx:1.27-alpine AS runtime
COPY nginx.conf /etc/nginx/nginx.conf
COPY --from=build /app/dist /usr/share/nginx/html
EXPOSE 80
