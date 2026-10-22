# Домашняя работа 4: Keycloak в Helm

Собственный Helm-чарт для задания со слайда 34. Реализованы dev-режим,
production-режим и HTTPS с самоподписанным сертификатом (вариант на 10).
Фотоотчёт с результатами запуска: [REPORT.md](REPORT.md).

## Что разворачивается и зачем

| Ресурс | Назначение |
| --- | --- |
| Deployment `keycloak` | Одна реплика сервера авторизации. `start-dev` в dev, `start` в prod. |
| ConfigMap `keycloak-config` | Адрес PostgreSQL, hostname, настройки HTTPS, health и metrics. |
| Secret `keycloak-credentials` | Пароли администратора и PostgreSQL. Создаётся `setup.sh` вне Helm; пароли не записываются в values. |
| Secret `keycloak-tls` | Сертификат и закрытый ключ. Монтируется в Keycloak только в prod. |
| Service `keycloak` | Доступ к приложению внутри кластера: HTTP 8080 в dev или HTTPS 8443 в prod. |
| StatefulSet `keycloak-postgresql` | PostgreSQL с постоянным именем Pod и привязанным к нему диском. |
| Headless Service `keycloak-postgresql` | Стабильное DNS-имя БД внутри namespace. |
| PVC `data-keycloak-postgresql-0` | 1 GiB для пользователей, realms, клиентов и других данных Keycloak. |
| Pod `keycloak-test-oidc` | Helm test проверяет OIDC discovery, ожидаемый issuer и доверие к сертификату в prod. |

Имена в таблице относятся к release `keycloak`. Другие release names создают
свои ресурсы. Namespace создаёт скрипт, PV выделяет StorageClass кластера.
Сторонние чарты и Ingress-контроллер не нужны: TLS завершается в самом Keycloak.

Проверки `/health/started`, `/health/ready`, `/health/live` идут на внутренний
management-порт 9000. Service этот порт не публикует. Startup probe даёт время
на сборку конфигурации и миграции БД, readiness управляет подачей трафика,
liveness перезапускает зависший контейнер. Включены requests/limits,
запуск без root и отключена передача Pod токена Kubernetes API.

## Подготовка

Нужны Docker или Podman, kind, kubectl, Helm 3, OpenSSL. Все команды ниже
выполняются из этой директории. Для отдельного учебного кластера:

```bash
mkdir -p .local
kind create cluster --name homework-4 --kubeconfig "$PWD/.local/kubeconfig"
export KUBECONFIG="$PWD/.local/kubeconfig"
kubectl get nodes
```

Для Podman добавьте `KIND_EXPERIMENTAL_PROVIDER=podman` перед `kind create`.
У kind есть стандартный StorageClass. В другом кластере нужен provisioner
для PVC; имя класса можно задать через `postgresql.persistence.storageClass`.

## Production и HTTPS

```bash
./setup.sh prod
kubectl -n keycloak-prod get deployment,statefulset,pods,svc,pvc
kubectl -n keycloak-prod port-forward svc/keycloak 8443:8443
```

Скрипт создаёт namespace `keycloak-prod`, случайные пароли и сертификат RSA 2048
с SAN для `localhost`, `127.0.0.1` и DNS-имён сервиса. Затем выполняет
`helm upgrade --install --wait` и `helm test`. При повторном запуске сохраняет
имеющиеся Secrets. Локальные материалы находятся в игнорируемой `.local/`
с ограниченными правами. Секреты также остаются при `helm uninstall`, чтобы
сохранённая БД не потеряла свой пароль.

В другом терминале (с тем же `KUBECONFIG`):

```bash
# Сохранить только публичный сертификат для клиента.
kubectl -n keycloak-prod get secret keycloak-tls \
  -o jsonpath='{.data.tls\.crt}' | openssl base64 -d -A > .local/ca.crt

# Проверяет доверие к сертификату и соответствие имени. Без curl -k.
curl --cacert .local/ca.crt \
  https://localhost:8443/realms/master/.well-known/openid-configuration

# Посмотреть пароль локально; не включать этот вывод в фотоотчёт.
kubectl -n keycloak-prod get secret keycloak-credentials \
  -o jsonpath='{.data.admin-password}' | openssl base64 -d -A
```

Админка: <https://localhost:8443/admin/>, пользователь `admin`.
Браузер предупредит о недоверенном самоподписанном сертификате: это ожидаемо.
Для доступа через браузер можно доверить публичный сертификат в своей тестовой
среде. Для настоящего сервера нужен сертификат доверенного CA и реальный hostname.
`KC_HTTP_ENABLED=false`: в prod пользовательские запросы обслуживаются по HTTPS.

## Dev-режим

```bash
./setup.sh dev
kubectl -n keycloak-dev port-forward svc/keycloak 8080:8080
```

Админка: <http://localhost:8080/admin/>. Пароль берётся той же командой из
namespace `keycloak-dev`. В dev запускается `start-dev`, TLS выключен, БД
остаётся PostgreSQL с отдельным PVC. Dev и prod установлены в разных namespace
и могут работать одновременно, не разделяя пользователей или пароли.

## Проверки, обновление и сохранность данных

```bash
helm lint ./keycloak --strict -f values-prod.yaml
helm lint ./keycloak --strict -f values-dev.yaml
helm template keycloak ./keycloak -f values-prod.yaml
helm test keycloak -n keycloak-prod --logs
helm test keycloak -n keycloak-dev --logs
```

Для проверки диска создайте realm `homework4-demo` через админку, затем:

```bash
kubectl -n keycloak-prod exec keycloak-postgresql-0 -- \
  psql -U keycloak -d keycloak -c 'SELECT name FROM realm;'
kubectl -n keycloak-prod delete pod keycloak-postgresql-0
kubectl -n keycloak-prod rollout status statefulset/keycloak-postgresql --timeout=120s
kubectl -n keycloak-prod exec keycloak-postgresql-0 -- \
  psql -U keycloak -d keycloak -c 'SELECT name FROM realm;'
```

После пересоздания Pod realm остаётся в БД: StatefulSet подключил прежний PVC.
`kubectl rollout restart deployment/keycloak -n keycloak-prod` также сохраняет
данные. После рестарта Keycloak заново запустите `port-forward`.

Изменения values применяются командой:

```bash
helm upgrade keycloak ./keycloak -n keycloak-prod -f values-prod.yaml --wait --timeout 10m
helm history keycloak -n keycloak-prod
```

Изменение ConfigMap автоматически обновляет Pod благодаря checksum-аннотации.
При ручном изменении паролей в Secret потребуется согласованная смена пароля
в самой БД/Keycloak: bootstrap-переменные не переопределяют уже созданных
пользователей. Не удаляйте Secret, пока нужен существующий PVC.

Это учебная установка в **production-режиме Keycloak**, с одной репликой и
`Recreate`: обновление даёт короткий простой. Здесь нет HA, резервного копирования
и репликации PostgreSQL. PVC kind переживает перезапуск Pod, но не гарантирует
сохранность при потере узла или удалении всего кластера.

## Удаление

```bash
# Удаляет приложение. PostgreSQL PVC и созданные скриптом Secrets сохраняются.
helm uninstall keycloak -n keycloak-prod
helm uninstall keycloak -n keycloak-dev

# Только когда учебные данные больше не нужны: удаляет весь тестовый кластер.
kind delete cluster --name homework-4
```

## Документация

- [Keycloak в контейнере](https://www.keycloak.org/server/containers)
- [TLS в Keycloak](https://www.keycloak.org/server/enabletls)
- [Health checks](https://www.keycloak.org/observability/health)
- [Helm tests](https://helm.sh/docs/topics/chart_tests/)
- [StatefulSet и постоянные тома](https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/)
