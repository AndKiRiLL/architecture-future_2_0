# Задание 2. GitLab CI/CD и удалённое состояние

Одна конфигурация Terraform, один удалённый state в Yandex Object Storage
и pipeline GitLab CI/CD: `init` → `plan` → ручной `apply`.
Используется модуль ВМ из первого задания, без его изменения.

## Структура

```text
Task2Advanced/
├── .gitlab-ci.yml
├── main.tf
├── variables.tf
├── outputs.tf
├── terraform.tfvars
├── backend.tf
├── backend.hcl
├── .terraform.lock.hcl
└── README.md
```

- `main.tf` настраивает провайдер и вызывает `../Task1Advanced/modules/vm`.
- `variables.tf` объявляет параметры ВМ, ID облака, каталога, подсети и SSH-ключ.
- `outputs.tf` выводит ID, имя и IP-адреса ВМ, ID дополнительного диска.
- `terraform.tfvars` содержит параметры ВМ: 2 ядра, 2 ГБ RAM,
  дополнительный диск 10 ГБ. Этот файл Terraform загружает автоматически.
- `backend.tf` задаёт S3 backend и HTTPS endpoint Yandex Object Storage.
- `backend.hcl` задаёт ключ `task2/terraform.tfstate`.
- `.terraform.lock.hcl` фиксирует провайдер и контрольные суммы для Linux и Windows.
- `.gitlab-ci.yml` описывает pipeline.

## Подготовка хранилища и аккаунта

До запуска pipeline подготовьте в Yandex Cloud:

1. Каталог и подсеть в зоне, указанной в `terraform.tfvars`.
2. Приватный бакет Object Storage. Запретите публичный доступ и включите
   версионирование для восстановления предыдущих версий state.
3. Сервисный аккаунт с `compute.editor` и `vpc.user` на целевом каталоге,
   а также доступом `storage.editor` к выбранному бакету.
4. Статический ключ доступа для S3 API: access key ID и secret access key.
5. Авторизованный JSON-ключ сервисного аккаунта для Terraform-провайдера.

Бакет создаётся заранее: backend не может создать собственное хранилище
во время `terraform init`. Ключи доступа не записываются в код или `.tfvars`.

## Переменные GitLab

В GitLab откройте **Settings → CI/CD → Variables** и добавьте:

| Имя | Значение | Тип |
| --- | --- | --- |
| `TF_STATE_BUCKET` | Имя бакета без `s3://` | Variable |
| `AWS_ACCESS_KEY_ID` | Идентификатор статического S3-ключа | Variable |
| `AWS_SECRET_ACCESS_KEY` | Секретная часть статического S3-ключа | Variable |
| `YC_SERVICE_ACCOUNT_KEY_FILE` | Полное содержимое авторизованного JSON-ключа | File |
| `TF_VAR_cloud_id` | ID облака | Variable |
| `TF_VAR_folder_id` | ID каталога | Variable |
| `TF_VAR_subnet_id` | ID подсети | Variable |
| `TF_VAR_ssh_public_key` | Полная строка публичного SSH-ключа | Variable |

Для всех этих настроек включите **Protected**. Для статических ключей
дополнительно включите **Masked** и отключите подстановку ссылок на другие
переменные. JSON-ключ хранится как File: GitLab создаёт временный файл и
передаёт его путь через `YC_SERVICE_ACCOUNT_KEY_FILE`. Закрытый SSH-ключ не нужен.

Файл pipeline находится в папке задания. Чтобы GitLab его использовал,
в **Settings → CI/CD → General pipelines → CI/CD configuration file**
укажите путь:

```text
Task2Advanced/.gitlab-ci.yml
```


В Settings → Repository → Branch rules проверьте, что основная ветка, обычно main, отмечена как Protected. Это необходимо для запуска plan и apply с защищёнными переменными. Для проверки Merge Request доступ к облачным ключам оставьте выключенным.

В Settings → CI/CD → Runners должен быть доступен runner с поддержкой Docker-образов. Он выполняет команды pipeline и должен иметь доступ к интернету и Yandex Cloud.

## Pipeline

### validate

Запускается в pipeline ветки и Merge Request:

```bash
terraform fmt -check -recursive .
terraform init -backend=false -input=false -lockfile=readonly
terraform validate
```

Рабочая директория — `Task2Advanced`. Для этой проверки backend отключён:
подключение к бакету и облачные ключи не нужны. Ресурсы не создаются.

### plan

Запускается после успешной проверки только в **защищённой основной ветке**.
Скрипт сначала проверяет наличие нужных переменных и JSON-файла, затем:

```bash
terraform init -input=false -lockfile=readonly \
  -backend-config=backend.hcl \
  -backend-config="bucket=$TF_STATE_BUCKET"
terraform plan -input=false -out=tfplan
```

Имя бакета поступает из CI/CD Variables, параметры ВМ — из `terraform.tfvars`,
остальные входные параметры — из переменных `TF_VAR_*`.

Сохранённый план `Task2Advanced/tfplan` передаётся следующему job как artifact.
Срок хранения — один час; скачивание доступно участникам с ролью Developer
и выше. План может содержать чувствительные данные, поэтому доступ к проекту,
логам и artifacts должен быть ограничен доверенными участниками.

### apply

После просмотра результата `plan` нажмите кнопку запуска ручного job `apply`.
В нём повторяется `terraform init` с тем же remote backend и выполняется:

```bash
terraform apply -input=false tfplan
```

Применяется сохранённый план этого pipeline. Новый план на этапе apply
не строится. Пока кнопка не нажата, изменения не применяются. `apply`
создаёт платные ресурсы. Если artifact уже истёк или состояние изменилось
после plan, запустите новый pipeline и проверьте новый план.

## Состояние и безопасность

Состояние хранится в бакете `TF_STATE_BUCKET` по ключу
`task2/terraform.tfstate`. Локальный state первого задания автоматически
не переносится: здесь создаётся отдельная ВМ `future-ci-vm`.

Отключённые в `backend.tf` проверки AWS нужны для совместимости с
Yandex Object Storage. TLS-проверка включена, авторизацию проверяет хранилище.
Backend получает ключи из `AWS_ACCESS_KEY_ID` и `AWS_SECRET_ACCESS_KEY`;
секреты не сохраняются в backend-конфигурации.

Jobs `plan` и `apply` имеют один `resource_group: task2-state`, поэтому
не выполняются одновременно даже из разных pipeline. Между plan и ручным
apply другой pipeline может обновить state: Terraform отклонит устаревший
план, и потребуется новый pipeline.

Распределённая блокировка S3 state в этом решении не настроена. Все операции
изменения выполняйте через этот pipeline; нельзя параллельно запускать
локальный apply/destroy или другой pipeline для того же state.

Каталог `.terraform/` хранит служебные данные backend и провайдеры,
а не локальное рабочее состояние инфраструктуры. При сбое сохранения
удалённого state Terraform может записать аварийный локальный state:
его нужно сохранить вне Git и восстановить запись по инструкции Terraform.
State, `.terraform/` и файлы плана исключены из Git через `.gitignore`.

## Локальная проверка без облака

Из корня репозитория в Git Bash или PowerShell:

```text
terraform fmt -check -recursive Task2Advanced
terraform -chdir=Task2Advanced init -backend=false -input=false -lockfile=readonly
terraform -chdir=Task2Advanced validate
```

Ожидаемый результат последней команды:

```text
Success! The configuration is valid.
```

Эти команды проверяют Terraform-код, но не соединение с бакетом, IAM-права
или реальный запуск GitLab CI/CD.

Для функциональной проверки запустите pipeline в настроенном GitLab-проекте,
просмотрите plan и подтвердите apply. После успешного apply проверьте наличие
объекта `task2/terraform.tfstate` в бакете. Повторный plan без изменения
конфигурации должен показать отсутствие изменений.

## Если Terraform Registry недоступен

Если `terraform init` завершается ошибкой `context deadline exceeded`
при обращении к `registry.terraform.io`, можно использовать официальное
зеркало провайдеров Yandex Cloud.

Ниже приведены команды для Windows с Git Bash.

### 1. Создайте локальный файл настроек

Откройте файл вне репозитория:

```bash
notepad "$HOME/terraform-yandex.tfrc"
```

Добавьте следующие настройки:

```hcl
provider_installation {
  network_mirror {
    url     = "https://terraform-mirror.yandexcloud.net/"
    include = ["registry.terraform.io/yandex-cloud/yandex"]
  }
}
```

Сохраните файл как `terraform-yandex.tfrc`, без дополнительного расширения
`.txt`. Если этот файл уже создан, проверьте его содержимое.

### 2. Подключите настройки

В том же терминале выполните:

```bash
export TF_CLI_CONFIG_FILE="$(cygpath -m "$HOME/terraform-yandex.tfrc")"
```

Переменная действует в текущем терминале. После открытия нового терминала
команду нужно выполнить повторно.

### 3. Повторите локальную проверку

Из корня репозитория:

```bash
terraform -chdir=Task2Advanced init -backend=false -input=false
terraform -chdir=Task2Advanced validate
```

Ожидаемый результат:

```text
Success! The configuration is valid.
```
