# Установка Docker и Docker Compose для проекта BSBD Lab1

## Системные требования

- Linux (Debian/Ubuntu рекомендуется)
- Минимум 2 ГБ свободной оперативной памяти
- Минимум 5 ГБ свободного места на диске

## Установка Docker

### Для Debian/Ubuntu

#### 1. Обновление системы
```bash
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg lsb-release
```

#### 2. Добавление официального GPG-ключа Docker
```bash
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
```

#### 3. Настройка репозитория Docker
```bash
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
```

#### 4. Установка Docker Engine
```bash
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

#### 5. Проверка установки
```bash
sudo docker --version
sudo docker compose version
```

#### 6. Настройка прав доступа (опционально, но рекомендуется)
Добавьте вашего пользователя в группу `docker`, чтобы запускать Docker без `sudo`:

```bash
sudo usermod -aG docker $USER
```

**Важно**: После добавления в группу нужно выйти и зайти в систему заново (или выполнить `newgrp docker`) для применения изменений.

Проверка работы без sudo:
```bash
docker --version
docker compose version
```

### Для других дистрибутивов Linux

#### CentOS/RHEL/Fedora
```bash
# Установка необходимых пакетов
sudo yum install -y yum-utils

# Добавление репозитория Docker
sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo

# Установка Docker
sudo yum install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Запуск Docker
sudo systemctl start docker
sudo systemctl enable docker

# Добавление пользователя в группу docker
sudo usermod -aG docker $USER
```

#### Arch Linux
```bash
sudo pacman -S docker docker-compose
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker $USER
```

## Установка Docker Compose (если не установлен вместе с Docker)

Современные версии Docker включают Docker Compose как плагин (`docker compose`), но если нужна standalone версия:

```bash
# Скачивание последней версии Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose

# Установка прав на выполнение
sudo chmod +x /usr/local/bin/docker-compose

# Проверка установки
docker-compose --version
```

**Примечание**: Проект использует новый синтаксис `docker compose` (без дефиса), который доступен как плагин Docker.

## Запуск приложения

### 1. Переход в директорию проекта
```bash
cd /home/zinin/bsbd_lab1
```

### 2. Запуск контейнеров
```bash
docker compose up -d
```

Флаг `-d` запускает контейнеры в фоновом режиме.

### 3. Проверка статуса контейнеров
```bash
docker compose ps
```

Вы должны увидеть два контейнера:
- `bsbd_lab1_db` (PostgreSQL)
- `bsbd_lab1_pgadmin` (pgAdmin)

### 4. Просмотр логов (опционально)
```bash
# Все логи
docker compose logs

# Логи конкретного сервиса
docker compose logs postgres
docker compose logs pgadmin

# Логи в реальном времени
docker compose logs -f
```

### 5. Остановка контейнеров
```bash
docker compose down
```

### 6. Остановка и удаление данных
```bash
docker compose down -v
```

**Внимание**: Это удалит все данные базы данных!

## Применение миграции ЛР4

После запуска контейнеров примените миграцию:

```bash
docker exec bsbd_lab1_db psql -U postgres -d bsbd_lab1 -f /migrate_lab4.sql
```

## Доступ к приложению

- **PostgreSQL**: `localhost:5433`
  - Пользователь: `postgres`
  - Пароль: `123`
  - База данных: `bsbd_lab1`

- **pgAdmin**: http://localhost:8080
  - Email: `admin@example.com`
  - Пароль: `123`

## Решение проблем

### Ошибка "Permission denied"
Если получаете ошибку доступа, убедитесь, что вы в группе docker:
```bash
groups  # Проверьте, есть ли docker в списке
newgrp docker  # Или перезайдите в систему
```

### Порт уже занят
Если порты 5433 или 8080 заняты, измените их в `docker-compose.yml`:
```yaml
ports:
  - "5434:5432"  # Вместо 5433
  - "8081:80"    # Вместо 8080
```

### Контейнеры не запускаются
Проверьте логи:
```bash
docker compose logs
```

Проверьте, что Docker запущен:
```bash
sudo systemctl status docker
```

Если Docker не запущен:
```bash
sudo systemctl start docker
sudo systemctl enable docker  # Автозапуск при загрузке
```

### Проверка версии Docker Compose
Убедитесь, что используется правильная версия:
```bash
docker compose version
# Должно быть: Docker Compose version v2.x.x
```

Если установлена только старая версия `docker-compose` (с дефисом), обновите Docker или установите плагин:
```bash
docker compose version
```

## Дополнительные команды

### Перезапуск контейнеров
```bash
docker compose restart
```

### Остановка конкретного сервиса
```bash
docker compose stop postgres
```

### Запуск конкретного сервиса
```bash
docker compose start postgres
```

### Подключение к контейнеру PostgreSQL
```bash
docker exec -it bsbd_lab1_db psql -U postgres -d bsbd_lab1
```

### Очистка неиспользуемых ресурсов Docker
```bash
docker system prune -a  # Удаляет все неиспользуемые контейнеры, образы, сети
```

## Полезные ссылки

- [Официальная документация Docker](https://docs.docker.com/)
- [Документация Docker Compose](https://docs.docker.com/compose/)
- [Установка Docker на Linux](https://docs.docker.com/engine/install/)

