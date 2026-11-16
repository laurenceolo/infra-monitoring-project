# Infra Monitoring Project

Практическая работа по дисциплине «Программная инженерия. Часть 1».

**Состав:** Git/GitHub, Wireshark, Bash, Docker Compose, GitHub Actions, SSH/SCP.

## 1. Структура

```text
infra-monitoring-project/
├── .github/workflows/ci.yml  # CI при открытии Pull Request в main
├── nginx/default.conf        # Nginx reverse proxy → api:8080
├── check_api.sh              # Проверка HTTP-кода по URL
├── analyze_logs.sh           # Генерация и анализ 360 строк access.log
├── docker-compose.yml        # Сервисы api и proxy + внутренняя сеть
├── .gitignore                # Исключения для временных и log-файлов
└── README.md
```

## 2. Запуск Bash-скриптов

Нужны Bash, curl, awk, grep, sort, uniq (есть в Linux и macOS).

```bash
chmod +x check_api.sh analyze_logs.sh
./check_api.sh https://httpbin.org/status/200
# Ожидаемый текст: API доступен, код возврата 0

echo $?
./check_api.sh https://httpbin.org/status/404
# Ожидаемый текст: API недоступен, код ответа: 404; код возврата 1

echo $?
./analyze_logs.sh
# Создаёт 360 записей access.log, печатает общее количество,
# три наиболее частых IP-адреса, число запросов со статусами 4xx/5xx.
wc -l access.log

# Анализ любого существующего access.log:
./analyze_logs.sh /path/to/access.log

# Проверка синтаксиса:
bash -n check_api.sh && bash -n analyze_logs.sh
```

В `analyze_logs.sh` данные **синтетические**, а не результат реального перехвата. Для отчёта приложите скриншот фактического вывода терминала.

## 3. Docker Compose: API и обратный прокси

Требуется Docker Desktop / Docker Engine c Compose v2.

```bash
docker compose config            # Валидация yaml
# Равнозначное для старых установок: docker-compose config

docker compose up -d
docker compose ps
curl -i http://localhost:80/
# Тело HTTP-ответа: Monitoring Service Active

docker compose logs --tail=30
# Остановка и удаление контейнеров:
docker compose down
```

- `api` использует готовый образ `hashicorp/http-echo:1.0.0`, слушает порт **8080** только внутри сети Docker.
- `proxy` использует готовый образ `nginx:alpine`, принимает соединения на **80** и перенаправляет запросы к `http://api:8080`.
- Оба сервиса входят в одну пользовательскую bridge-сеть `monitoring-net`.
- Если порт 80 на компьютере уже занят, сначала освободите его; задание явно требует `curl http://localhost:80`.

## 4. Wireshark: реальная запись HTTP-трафика

> Важно: Wireshark нельзя заменить скриншотом тестового лога. Нужен **реальный захват пакетов** на собственной машине.

1. Запустите Wireshark, выберите активный сетевой интерфейс (Wi-Fi) и начните захват.
2. В другом окне терминала выполните запросы к внешнему публичному API:

   ```bash
   curl -i 'https://httpbin.org/get?project=monitoring'
   curl -i -X POST https://httpbin.org/post -H 'Content-Type: application/json' -d '{"project":"monitoring"}'
   curl -i https://httpbin.org/status/404
   ```

3. Для внешних **HTTPS** запросов используйте фильтр `tls || tcp.port == 443`. При обычном захвате TLS шифрует HTTP-метод и статус — в Wireshark их не видно в открытом виде. Метод и код ответа подтверждайте отдельно выводом `curl -i`.
4. Для отчётливого скриншота **незашифрованного HTTP** запустите контейнеры (`docker compose up -d`), начните захват на loopback-интерфейсе (`lo0` на macOS, `lo` на Linux) и выполните:

   ```bash
   curl -i http://localhost:80/
   curl -i -X POST http://localhost:80/
   ```

   Используйте фильтр `http || tcp.port == 80`. Если пакетов не видно, проверьте доступный интерфейс Docker Desktop/loopback; захват локального Docker-трафика зависит от системы.
5. Сохраните захват через File → Save As в `evidence/http_capture.pcapng` (директорию `evidence/` создайте вручную). Сделайте скриншот Wireshark с фильтром `http` и отчётливо видимыми пакетами.
6. В отчёте укажите **фактически увиденные** адреса источника и назначения, методы GET/POST и коды ответов. Для HTTPS IP-адреса и наличие соединения видны, но данные HTTP могут быть скрыты TLS.

## 5. Git workflow и CI/CD

Создайте на GitHub **пустой публичный репозиторий** с именем `infra-monitoring-project`, НЕ добавляйте автогенерируемый README в веб-интерфейсе.

Перейдите в распакованную папку проекта и выполните (замените `USERNAME`):

```bash
git init -b main
git add README.md .gitignore
git commit -m "docs: initialize repository"
git remote add origin https://github.com/USERNAME/infra-monitoring-project.git
git push -u origin main

# Настройте защиту main через GitHub Settings → Rules → Rulesets
# (требовать PR перед слиянием и, если нужно, успешного CI).

git switch -c feature/monitoring
git add check_api.sh analyze_logs.sh
git commit -m "feat: add API monitoring and HTTP log analysis scripts"
git add docker-compose.yml nginx/default.conf
git commit -m "feat: add Docker Compose API and Nginx proxy"
git add .github/workflows/ci.yml
git commit -m "ci: validate Bash scripts on pull requests"
git push -u origin feature/monitoring
```

Затем откройте GitHub → **Compare & pull request** → base `main`, compare `feature/monitoring`. Добавьте осмысленное описание и дождитесь зелёной проверки `Check Bash scripts / verify`. **Не сливайте PR до создания скриншота**; сохраните ссылку на PR для отчёта.

Если `git push` попросит аутентификацию, используйте GitHub CLI (`gh auth login`) или актуальный способ аутентификации GitHub; пароль от аккаунта в HTTPS Git не используется.

### Описание PR (пример)

```text
## Что изменилось
- Добавлены Bash-скрипты проверки HTTP API и анализа 360 тестовых записей.
- Подготовлена двухконтейнерная конфигурация API + Nginx с отдельной сетью.
- Добавлен CI: проверка bash -n, доступности httpbin 200 и анализа логов.
- Документированы локальный запуск, сетевой захват, SSH/SCP.

## Как проверить
- bash -n check_api.sh && bash -n analyze_logs.sh
- ./check_api.sh https://httpbin.org/status/200
- ./analyze_logs.sh
- docker compose up -d && curl http://localhost:80/
```

## 6. Защищённая передача файлов по SSH/SCP

**Генерация SSH-ключей** (не перезаписывайте уже существующий ключ):

```bash
ssh-keygen -t ed25519 -C "infra-monitoring-project" -f ~/.ssh/infra_monitoring_ed25519
```

**Копирование публичного ключа на сервер** (если есть `ssh-copy-id`):

```bash
ssh-copy-id -i ~/.ssh/infra_monitoring_ed25519.pub USER@SERVER_IP
```

В macOS без `ssh-copy-id` при уже настроенном безопасном доступе к серверу можно добавить **только публичный** ключ вручную в `~/.ssh/authorized_keys` соответствующего пользователя. Никогда не копируйте приватный ключ на сервер или в репозиторий.

**Передача проекта** (из родительской директории):

```bash
tar -czf infra-monitoring-project.tar.gz infra-monitoring-project/ \
  --exclude='.git' --exclude='access.log'
scp -i ~/.ssh/infra_monitoring_ed25519 infra-monitoring-project.tar.gz USER@SERVER_IP:/home/USER/
ssh -i ~/.ssh/infra_monitoring_ed25519 USER@SERVER_IP
```

На macOS BSD `tar` поставьте `--exclude` **перед** именем директории либо используйте:

```bash
tar --exclude='.git' --exclude='access.log' -czf infra-monitoring-project.tar.gz infra-monitoring-project/
```

Для передачи по потоку (без промежуточного файла):

```bash
tar --exclude='.git' --exclude='access.log' -czf - infra-monitoring-project/ \
  | ssh -i ~/.ssh/infra_monitoring_ed25519 USER@SERVER_IP 'cat > infra-monitoring-project.tar.gz'
```

SSH/SCP-команды — **примеры**. Для отчёта их выполнения реальный удалённый сервер не требуется, если преподаватель не поставил такое отдельное условие.

## 7. Что приложить в отчёт

- Скриншот Wireshark с фильтром `http` + настоящий `.pcapng`.
- Таблица IP-адресов, методов и ответов (взятая из собственного захвата и `curl -i`).
- Скриншот терминала с `./analyze_logs.sh` и `wc -l access.log`.
- Скриншот `docker compose ps` (два работающих контейнера) и `curl http://localhost:80`.
- Скриншот успешного GitHub Actions workflow, ссылка на Pull Request.
- Описание генерации SSH-ключа и передачи через SCP в README.

Дайте преподавателю две ссылки: **GitHub репозиторий** и **отчёт Word/PDF** (с доступом на просмотр). Файл `.pcapng` тоже должен быть доступен проверяющему: приложите отдельно к отчёту или дайте ссылку.

## 8. Возможные проблемы

- `port is already allocated`: освободите порт 80 либо временно смените на 8081, но для зачёта восстановите порт 80.
- `curl: (7) Failed to connect`: сначала проверьте `docker compose ps`, затем `docker compose logs proxy api`.
- HTTP-запросы к `https://...` не видны как HTTP в Wireshark: это ожидаемо, поскольку они зашифрованы TLS.
- CI не смог обратиться к httpbin.org: повторите запуск; внешняя сеть GitHub может быть временно недоступна. Если проблема повторяется, проверьте HTTP-статус и сетевые правила.
