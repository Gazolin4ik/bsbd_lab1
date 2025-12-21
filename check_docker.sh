#!/bin/bash

# Скрипт проверки установки Docker и Docker Compose

echo "=========================================="
echo "ПРОВЕРКА УСТАНОВКИ DOCKER"
echo "=========================================="

# Проверка Docker
if command -v docker &> /dev/null; then
    DOCKER_VERSION=$(docker --version)
    echo "✓ Docker установлен: $DOCKER_VERSION"
else
    echo "✗ Docker НЕ установлен"
    echo "  Установите Docker, следуя инструкциям в INSTALL_DOCKER.md"
    exit 1
fi

# Проверка Docker Compose
if docker compose version &> /dev/null; then
    COMPOSE_VERSION=$(docker compose version)
    echo "✓ Docker Compose установлен: $COMPOSE_VERSION"
elif command -v docker-compose &> /dev/null; then
    COMPOSE_VERSION=$(docker-compose --version)
    echo "✓ Docker Compose установлен (старая версия): $COMPOSE_VERSION"
    echo "  Рекомендуется использовать 'docker compose' (плагин)"
else
    echo "✗ Docker Compose НЕ установлен"
    echo "  Установите Docker Compose, следуя инструкциям в INSTALL_DOCKER.md"
    exit 1
fi

# Проверка прав доступа
if docker ps &> /dev/null; then
    echo "✓ Права доступа к Docker настроены корректно"
else
    echo "⚠ Недостаточно прав для запуска Docker без sudo"
    echo "  Добавьте пользователя в группу docker:"
    echo "    sudo usermod -aG docker \$USER"
    echo "    newgrp docker  # или перезайдите в систему"
fi

# Проверка запущенного Docker daemon
if docker info &> /dev/null; then
    echo "✓ Docker daemon запущен"
else
    echo "✗ Docker daemon НЕ запущен"
    echo "  Запустите Docker: sudo systemctl start docker"
    exit 1
fi

echo "=========================================="
echo "ПРОВЕРКА ЗАВЕРШЕНА"
echo "=========================================="
echo ""
echo "Для запуска приложения выполните:"
echo "  docker compose up -d"
echo ""

