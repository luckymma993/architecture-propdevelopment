# Задание 4. Ролевая модель доступа (RBAC) в Kubernetes

## Как разделены доступы

Сервисы компании разложены по пространствам имён (namespace) в соответствии с доменами:

| Namespace | Домен | Сервисы |
|---|---|---|
| `sales` | Продажи | витрина продаж, client-mart-app, client-mart-estate-app, client-tour-app, client-crm-app |
| `housing` | ЖКУ | tenant-core-app, CRM собственников, сервисы «Умного дома» |
| `finance` | Финансы | accountant-service-1 |
| `data` | Данные | загрузка в хранилище, BI |

Принципы:

- **Минимальные привилегии.** Каждая группа получает только те действия, которые нужны ей в работе.
- **Секреты отдельно.** Читать и менять Secret может только привилегированная группа. Разработчики и операторы секретов не видят, даже в своём namespace.
- **Права по оргструктуре.** Команда домена работает только в своём namespace. Разработчики продаж не видят ЖКУ и финансы.
- **Права выдаются группам, а не людям.** Группа задаётся в сертификате пользователя (поле `O`). Когда человек переходит в другую команду, ему перевыпускают сертификат, роли не меняются.
- **Изменение RBAC не делегируется.** Ни одна роль, кроме встроенного `cluster-admin`, не может создавать роли и привязки. Иначе любая группа могла бы выдать себе лишние права.

## Роли

| Роль | Права роли | Группы пользователей |
| --- | --- | --- |
| `secrets-admin` (ClusterRole, ClusterRoleBinding) | Привилегированная роль. Полный доступ к `secrets` и `serviceaccounts` во всех namespace: просмотр, создание, изменение, удаление, выпуск токенов. Вместе с `cluster-viewer` видит всё остальное в кластере. Не может менять конфигурацию кластера и приложения | `security-admins` — специалист по ИБ и ведущий DevOps-инженер (принцип четырёх глаз для работы с секретами) |
| `cluster-configurator` (ClusterRole, ClusterRoleBinding) | Настройка кластера: namespaces, ResourceQuota, LimitRange, NetworkPolicy, StorageClass, PersistentVolume, PriorityClass, CRD, admission webhooks, изменение узлов (cordon/drain). Секреты и RBAC менять не может | `devops-platform` — DevOps-инженеры платформенной команды |
| `cluster-viewer` (ClusterRole, ClusterRoleBinding) | Только просмотр (`get`, `list`, `watch`) почти всех ресурсов во всех namespace: поды, логи, сервисы, деплойменты, ConfigMap, события, узлы, сетевые политики, роли. **Без доступа к секретам** | `business-analysts` — бизнес-аналитики; `ops-engineers` — инженеры эксплуатации; `devops-platform` и `security-admins` — для обзора кластера |
| `namespace-developer` (ClusterRole, RoleBinding в namespace домена) | В своём namespace: создание и изменение Deployment, StatefulSet, Pod, Service, ConfigMap, Job, CronJob, Ingress, HPA, PVC; чтение логов и событий, port-forward. Секреты не видит, в чужие namespace доступа нет | `sales-developers` → `sales`; `housing-developers` → `housing`; `finance-developers` → `finance`; `data-engineers` → `data` |
| `namespace-operator` (ClusterRole, RoleBinding во всех доменных namespace) | Эксплуатация: просмотр ресурсов и логов, перезапуск подов (удаление), масштабирование Deployment и StatefulSet, `exec` в под для диагностики, ручной запуск Job. Создавать новые приложения и читать секреты не может | `ops-engineers` — инженеры эксплуатации |

Роли `namespace-developer` и `namespace-operator` описаны как ClusterRole, но привязываются через RoleBinding. Так одно описание прав переиспользуется во всех namespace, а действует только внутри конкретного namespace.

## Скрипты

| Скрипт | Что делает |
|---|---|
| [create-users.sh](create-users.sh) | Создаёт 6 пользователей. Для каждого генерирует ключ, запрос на сертификат с `CN=<пользователь>` и `O=<группа>`, подписывает его через Kubernetes CertificateSigningRequest и добавляет контекст в kubeconfig |
| [create-roles.sh](create-roles.sh) | Создаёт namespace доменов и пять ClusterRole |
| [bind-roles.sh](bind-roles.sh) | Связывает роли с группами: ClusterRoleBinding для кластерных ролей и RoleBinding для ролей внутри namespace |
| [check-access.sh](check-access.sh) | Проверяет права через `kubectl auth can-i` |

Пользователи:

| Пользователь | Группа |
|---|---|
| ivanov | security-admins |
| petrov | devops-platform |
| sidorova | business-analysts |
| orlov | ops-engineers |
| smirnov | sales-developers |
| kuznetsova | housing-developers |

Ключи и сертификаты сохраняются в `users/`. Папка исключена из git.

## Запуск

```bash
minikube start
./create-users.sh
./create-roles.sh
./bind-roles.sh
./check-access.sh
```

Проверка от имени пользователя:

```bash
kubectl --context=smirnov -n sales get pods
kubectl --context=smirnov -n housing get pods
```

## Результат проверки

Кластер Minikube v1.35.1, вывод `./check-access.sh`:

```
ivanov      security-admins      *        get secrets                              yes
ivanov      security-admins      *        create secrets                           yes
ivanov      security-admins      *        delete namespaces                        no
petrov      devops-platform      *        create namespaces                        yes
petrov      devops-platform      *        create networkpolicies                   yes
petrov      devops-platform      *        get secrets                              no
sidorova    business-analysts    *        list pods                                yes
sidorova    business-analysts    *        get secrets                              no
sidorova    business-analysts    sales    delete pods                              no
orlov       ops-engineers        housing  create pods --subresource=exec           yes
orlov       ops-engineers        housing  patch deployments/scale                  yes
orlov       ops-engineers        housing  create deployments                       no
smirnov     sales-developers     sales    create deployments                       yes
smirnov     sales-developers     housing  create deployments                       no
smirnov     sales-developers     sales    get secrets                              no
kuznetsova  housing-developers   housing  create services                          yes
kuznetsova  housing-developers   finance  list pods                                no
```

Проверка от имени пользователей:

```
$ kubectl --context=smirnov -n sales get pods
No resources found in sales namespace.

$ kubectl --context=smirnov -n housing get pods
Error from server (Forbidden): pods is forbidden: User "smirnov" cannot list resource "pods" in API group "" in the namespace "housing"

$ kubectl --context=sidorova -n sales get secrets
Error from server (Forbidden): secrets is forbidden: User "sidorova" cannot list resource "secrets" in API group "" in the namespace "sales"

$ kubectl --context=ivanov -n kube-system get secrets
NAME                     TYPE                            DATA   AGE
bootstrap-token-3uoty7   bootstrap.kubernetes.io/token   6      39s
```
