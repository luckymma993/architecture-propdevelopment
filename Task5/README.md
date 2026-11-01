# Задание 5. Сетевые политики Kubernetes

Цель: в одном namespace разрешить трафик только между `front-end` ↔ `back-end-api` и `admin-front-end` ↔ `admin-back-end-api`. Любое другое взаимодействие запрещено.

## Файлы

| Файл | Назначение |
|---|---|
| [non-admin-api-allow.yaml](non-admin-api-allow.yaml) | Сетевые политики |
| [check-network.sh](check-network.sh) | Проверка доступности сервисов между всеми парами ролей |

## Политики

| Политика | Применяется к подам | Разрешает входящий трафик от |
|---|---|---|
| `default-deny-ingress` | все поды namespace | никого — запрет по умолчанию |
| `back-end-api-allow-front-end` | `role=back-end-api` | `role=front-end` |
| `front-end-allow-back-end-api` | `role=front-end` | `role=back-end-api` |
| `admin-back-end-api-allow-admin-front-end` | `role=admin-back-end-api` | `role=admin-front-end` |
| `admin-front-end-allow-admin-back-end-api` | `role=admin-front-end` | `role=admin-back-end-api` |

Сначала весь входящий трафик запрещается, затем точечно открываются нужные пары. Политики в Kubernetes складываются: под принимает трафик, если его разрешает хотя бы одна политика. Исходящий трафик не ограничивается, чтобы поды могли обращаться к DNS кластера.

## Запуск

NetworkPolicy работает только с сетевым плагином, который её поддерживает. Стандартный плагин Minikube политики игнорирует, поэтому кластер запускается с Calico:

```bash
minikube start --cni=calico
```

Создание подов и сервисов:

```bash
kubectl run front-end-app --image=nginx --labels role=front-end --expose --port 80
kubectl run back-end-api-app --image=nginx --labels role=back-end-api --expose --port 80
kubectl run admin-front-end-app --image=nginx --labels role=admin-front-end --expose --port 80
kubectl run admin-back-end-api-app --image=nginx --labels role=admin-back-end-api --expose --port 80
```

Применение политик:

```bash
kubectl apply -f non-admin-api-allow.yaml
```

Ручная проверка: временный под с меткой `role=front-end` обращается к сервисам.

```bash
kubectl run test-$RANDOM --rm -i -t --image=alpine --labels role=front-end -- sh
wget -qO- --timeout=2 http://back-end-api-app
wget -qO- --timeout=2 http://admin-back-end-api-app
```

Первый запрос возвращает страницу nginx, второй завершается по таймауту.

## Результат проверки

Кластер Minikube v1.35.1 с Calico. `./check-network.sh` запускает временный под alpine с меткой исходной роли и выполняет `wget` к сервису целевой роли.

До применения политик всё открыто:

```
front-end            -> back-end-api         ALLOWED
front-end            -> admin-front-end      ALLOWED
front-end            -> admin-back-end-api   ALLOWED
back-end-api         -> front-end            ALLOWED
back-end-api         -> admin-front-end      ALLOWED
back-end-api         -> admin-back-end-api   ALLOWED
admin-front-end      -> front-end            ALLOWED
admin-front-end      -> back-end-api         ALLOWED
admin-front-end      -> admin-back-end-api   ALLOWED
admin-back-end-api   -> front-end            ALLOWED
admin-back-end-api   -> back-end-api         ALLOWED
admin-back-end-api   -> admin-front-end      ALLOWED
```

После применения `non-admin-api-allow.yaml`:

```
front-end            -> back-end-api         ALLOWED
front-end            -> admin-front-end      denied
front-end            -> admin-back-end-api   denied
back-end-api         -> front-end            ALLOWED
back-end-api         -> admin-front-end      denied
back-end-api         -> admin-back-end-api   denied
admin-front-end      -> front-end            denied
admin-front-end      -> back-end-api         denied
admin-front-end      -> admin-back-end-api   ALLOWED
admin-back-end-api   -> front-end            denied
admin-back-end-api   -> back-end-api         denied
admin-back-end-api   -> admin-front-end      ALLOWED
```

Под без метки `role` тоже не получает доступа:

```
$ kubectl run check-nolabel --rm -i --restart=Never --image=alpine -- wget -qO- --timeout=2 http://back-end-api-app
wget: download timed out
```
