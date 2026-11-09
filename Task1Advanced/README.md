# Задание 1. Модульная инфраструктура для нескольких сред

Переиспользуемый модуль `vm_module` создаёт в Yandex Cloud одну ВМ с
загрузочным диском и отдельным дополнительным диском. ВМ подключается к
существующей подсети через сетевой интерфейс. Подсеть передаётся по ID,
поэтому модуль не создаёт новую сеть при каждом использовании.

## Структура

```text
Task1Advanced/
├── README.md
├── modules/vm/
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
└── envs/
    ├── dev/
    ├── stage/
    └── prod/
```

В каждом окружении есть `main.tf`, `variables.tf`, `outputs.tf`, свой файл
`<окружение>.tfvars` и lock-файл провайдера. Все окружения используют один модуль.
Имена и параметры окружений задаются снаружи модуля.

## Параметры модуля

| Переменная | Тип | Назначение | Значение по умолчанию |
| --- | --- | --- | --- |
| `name` | string | Имя ВМ | Обязательная |
| `zone` | string | Зона ВМ и дисков | Обязательная |
| `cores` | number | Количество ядер CPU | Обязательная |
| `memory` | number | RAM, ГБ | Обязательная |
| `disk_size` | number | Размер дополнительного диска, ГБ | Обязательная |
| `subnet_id` | string | ID существующей подсети | Обязательная |
| `ssh_public_key` | string | Содержимое публичного SSH-ключа | Обязательная |
| `ssh_user` | string | Пользователь SSH | `ubuntu` |
| `image_family` | string | Семейство образа ОС | `ubuntu-2204-lts` |
| `platform_id` | string | Платформа ВМ | `standard-v3` |
| `boot_disk_size` | number | Размер загрузочного диска, ГБ | `20` |
| `disk_type` | string | Тип дисков | `network-hdd` |
| `nat` | bool | Публичный IP-адрес | `true` |

Окружения дополнительно принимают `cloud_id`, `folder_id` и
`ssh_public_key_path`. Последний задаёт путь к файлу публичного ключа
(по умолчанию `~/.ssh/id_ed25519.pub`); его содержимое передаётся в модуль
через `file(pathexpand(...))`. Закрытый ключ в Terraform не передаётся.

## Выходы

Модуль и каждое окружение возвращают:

- `vm_id` — ID ВМ;
- `vm_name` — имя ВМ;
- `internal_ip` — внутренний IP;
- `external_ip` — публичный IP, пустой при `nat = false`;
- `disk_id` — ID дополнительного диска.

## Конфигурации окружений

| Окружение | CPU | RAM, ГБ | Дополнительный диск, ГБ |
| --- | --- | --- | --- |
| dev | 2 | 2 | 10 |
| stage | 2 | 4 | 20 |
| prod | 4 | 8 | 50 |

Каждое окружение запускается из собственной директории и хранит свой локальный
Terraform state. Параметры можно изменить в соответствующем `.tfvars`.

## Подготовка

Нужны Terraform версии `>= 1.9.0, < 2.0.0`, Yandex Cloud CLI (`yc`),
облачный аккаунт с правами создания ВМ и дисков и существующая подсеть.
Используется провайдер `yandex-cloud/yandex` версии `~> 0.140.0`.

1. Настройте CLI командой `yc init`.
2. Передайте токен провайдеру через окружение:

   ```bash
   export YC_TOKEN="$(yc iam create-token)"
   ```

3. В `envs/dev/dev.tfvars`, `envs/stage/stage.tfvars` и
   `envs/prod/prod.tfvars` замените заглушки `REPLACE_WITH_...` на свои ID.
   Подсеть должна принадлежать указанному каталогу и находиться в той же зоне,
   что и ВМ (`zone`). ID можно посмотреть командами:

   ```bash
   yc resource-manager cloud list
   yc resource-manager folder list
   yc vpc subnet list
   ```

4. Укажите путь к существующему публичному SSH-ключу в
   `ssh_public_key_path`. Если ключа ещё нет, создайте его через
   `ssh-keygen -t ed25519`, сохранив в свободный путь без перезаписи своих ключей.

Токен не нужно записывать в `.tfvars` или коммитить в Git.

## Запуск

Команды выполняются из корня репозитория.

### dev

```bash
cd Task1Advanced/envs/dev
terraform init
terraform validate
terraform plan -var-file=dev.tfvars
terraform apply -var-file=dev.tfvars
terraform output
```

### stage

В новом терминале из корня репозитория:

```bash
cd Task1Advanced/envs/stage
terraform init
terraform validate
terraform plan -var-file=stage.tfvars
terraform apply -var-file=stage.tfvars
terraform output
```

### prod

В новом терминале из корня репозитория:

```bash
cd Task1Advanced/envs/prod
terraform init
terraform validate
terraform plan -var-file=prod.tfvars
terraform apply -var-file=prod.tfvars
terraform output
```

`apply` создаёт платные ресурсы. После применения можно подключиться к ВМ
командой `ssh ubuntu@<external_ip>`, используя свой закрытый SSH-ключ.
Сетевые правила подсети должны разрешать SSH от вашего адреса.
Дополнительный диск подключён к ВМ, но не отформатирован и не смонтирован:
это задание создаёт инфраструктуру.

Для удаления ресурсов выполните в директории соответствующего окружения:

```bash
terraform destroy -var-file=dev.tfvars
```

Для `stage` и `prod` укажите соответственно `stage.tfvars` и `prod.tfvars`.
Удаление уничтожает ВМ и созданные Terraform диски вместе с их данными.

## Локальная проверка без создания ресурсов

Из корня репозитория:

```bash
terraform fmt -check -recursive Task1Advanced
for environment in dev stage prod; do
  terraform -chdir="Task1Advanced/envs/$environment" init -backend=false -input=false
  terraform -chdir="Task1Advanced/envs/$environment" validate
done
```

Эта проверка не требует облачного токена. `plan` и `apply` требуют настоящих
ID, публичного ключа и действующей авторизации в Yandex Cloud.
