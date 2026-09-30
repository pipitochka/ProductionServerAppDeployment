# Домашняя работа 2

Стек состоит из Keycloak, PostgreSQL и Nginx Proxy Manager. PostgreSQL доступен
только во внутренней сети, а Keycloak подключён одновременно к сети базы данных
и к общей сети reverse-proxy.

## Запуск

```bash
cp .env.example .env
docker network create keycloak-npm
docker compose up -d

cd npm
./generate-certs.sh keycloak.local
docker compose up -d
```

Добавьте `127.0.0.1 keycloak.local` в `/etc/hosts`. Keycloak будет доступен по
`http://localhost:8080`, а админка Nginx Proxy Manager — по `http://localhost:81`
(логин `admin@example.com`, пароль `changeme`).

В Nginx Proxy Manager создайте Proxy Host с доменом `keycloak.local`, укажите
forward hostname `keycloak`, порт `8080`, включите Websockets Support. Для HTTPS
загрузите сгенерированные `npm/certs/server.crt` и `npm/certs/server.key` как
Custom SSL Certificate и назначьте его Proxy Host.

Проверка маршрутизации через Nginx Proxy Manager:

```bash
curl -H 'Host: keycloak.local' http://localhost
```

Остановка с удалением данных:

```bash
docker compose down -v
cd npm && docker compose down -v
docker network rm keycloak-npm
```
