# Домашняя работа 3

Пример веб-сервиса на Python для запуска в kind. Приложение читает сообщение из
ConfigMap, токен из Secret и предоставляет `/health` и `/ready` для probes.

## Запуск

Создайте кластер из `../create/kind-config.yaml`, если его ещё нет, затем:

```bash
kind create cluster --name k8s-lab --config ../create/kind-config.yaml
./deploy.sh
kubectl get pods,svc -n k8s-lab
kubectl port-forward -n k8s-lab svc/my-app 8080:80
curl http://localhost:8080/
```

`deploy.sh` собирает образ, загружает его в kind и применяет namespace,
ConfigMap, Secret, Deployment и Service. В Deployment настроены 3 реплики,
requests/limits, liveness/readiness probes и rolling update без недоступных
реплик.

## Демонстрация rollout и отката

Ниже намеренно используется несуществующий тег. Kubernetes создаст новый
ReplicaSet, но readiness не будет достигнута; затем возвращаем рабочий образ:

```bash
kubectl -n k8s-lab set image deployment/my-app my-app=my-app:v999-nonexistent
kubectl -n k8s-lab rollout status deployment/my-app --timeout=20s || true
kubectl -n k8s-lab get pods
kubectl -n k8s-lab rollout undo deployment/my-app
kubectl -n k8s-lab rollout status deployment/my-app --timeout=60s
```

Файл `deployment-broken.yaml` содержит тот же намеренно неверный вариант для
воспроизводимой демонстрации, а `deployment.yaml` — рабочую конфигурацию.
