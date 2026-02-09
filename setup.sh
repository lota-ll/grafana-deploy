#!/bin/bash
# ============================================================================
# EcoCharge Grafana Deployment Script (FIXED)
# Сервер: 192.168.100.30
# Datasource: PostgreSQL на 192.168.20.20:5432
# FIX: Виправлено проблему з "Unauthorized" при логіні
# ============================================================================

set -e

echo "=============================================="
echo "EcoCharge Grafana Deployment (FIXED)"
echo "=============================================="

# --- 1. Docker ---
echo ""
echo "[1/6] Перевірка Docker..."
if ! command -v docker &> /dev/null; then
    echo "⚠️  Docker не встановлено. Встановлюю..."
    curl -fsSL https://get.docker.com | sudo sh
    sudo apt install -y docker-compose-plugin
    sudo usermod -aG docker $USER
    echo ""
    echo "❗ Docker встановлено. Будь ласка:"
    echo "   1. Вийдіть з сесії: exit"
    echo "   2. Зайдіть знову"
    echo "   3. Запустіть цей скрипт повторно"
    exit 0
fi
echo "✅ Docker встановлено"

# --- 2. Зупинити існуючий Grafana якщо є ---
echo ""
echo "[2/6] Зупинка існуючого Grafana (якщо є)..."
if docker ps -a | grep -q ecocharge-grafana; then
    echo "   Знайдено існуючий контейнер, зупиняю..."
    docker stop ecocharge-grafana 2>/dev/null || true
    docker rm ecocharge-grafana 2>/dev/null || true
    echo "✅ Старий контейнер видалено"
else
    echo "✅ Немає старого контейнера"
fi

# --- 3. Видалити існуючий volume (щоб скинути пароль) ---
echo ""
echo "[3/6] Очищення Grafana volume..."
read -p "   Видалити існуючі дані Grafana (рекомендовано для виправлення)? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    docker volume rm grafana-deploy-fixed_grafana-data 2>/dev/null || true
    docker volume rm grafana-deploy_grafana-data 2>/dev/null || true
    echo "✅ Volume очищено"
else
    echo "⚠️  Volume залишено без змін (проблема може залишитися)"
fi

# --- 4. Перевірка зʼєднання з PostgreSQL ---
echo ""
echo "[4/6] Перевірка зʼєднання з CitrineOS PostgreSQL (192.168.20.20:5432)..."
if nc -zw3 192.168.20.20 5432 2>/dev/null; then
    echo "✅ PostgreSQL доступний"
else
    echo "⚠️  Не вдається зʼєднатися з PostgreSQL на 192.168.20.20:5432"
    echo "   Перевіряю firewall та connectivity..."
    
    # Перевірка ping
    if ping -c 1 -W 2 192.168.20.20 &>/dev/null; then
        echo "   ✅ Host 192.168.20.20 доступний (ping OK)"
        echo "   ⚠️  Але порт 5432 закритий - перевірте firewall!"
        echo ""
        echo "   Спробуйте на сервері CitrineOS (192.168.20.20):"
        echo "   sudo iptables -I INPUT 1 -p tcp -s 192.168.100.30 --dport 5432 -j ACCEPT"
    else
        echo "   ❌ Host 192.168.20.20 недоступний (ping failed)"
        echo "   Перевірте мережеву конфігурацію!"
    fi
    
    echo ""
    read -p "   Продовжити все одно? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# --- 5. Перевірка файлів ---
echo ""
echo "[5/6] Перевірка файлів..."
MISSING=0
for file in docker-compose.yml grafana.ini provisioning/datasources/datasources.yml provisioning/dashboards/dashboards.yml dashboards/ecocharge-csms-overview.json; do
    if [ ! -f "$file" ]; then
        echo "❌ $file не знайдено!"
        MISSING=1
    fi
done
if [ $MISSING -eq 1 ]; then
    echo "❌ Деякі файли відсутні."
    exit 1
fi
echo "✅ Всі файли на місці"

# --- 6. Запуск ---
echo ""
echo "[6/6] Запуск Grafana..."
docker compose up -d

# Очікування запуску
echo ""
echo "Очікування запуску Grafana..."
for i in $(seq 1 30); do
    if curl -sf http://localhost:3000/api/health > /dev/null 2>&1; then
        echo ""
        echo "✅ Grafana ready!"
        break
    fi
    sleep 2
    echo -n "."
done
echo ""

# --- Перевірка здоров'я ---
echo ""
echo "Перевірка стану..."
sleep 3

# Тест логіну
echo "Тестування логіну admin:admin..."
LOGIN_TEST=$(curl -s -X POST http://localhost:3000/api/login/ping -u admin:admin)
if echo "$LOGIN_TEST" | grep -q "message"; then
    echo "✅ Логін працює!"
else
    echo "⚠️  Логін може не працювати, перевірте вручну"
fi

# --- Статус ---
echo ""
echo "=============================================="
echo "Статус контейнерів:"
echo "=============================================="
docker compose ps
echo ""

# Перевірка логів на помилки
echo "Останні логи (перевірка помилок):"
docker compose logs --tail=20 grafana | grep -i "error\|fail\|unauthorized" || echo "✅ Немає критичних помилок"
echo ""

echo "=============================================="
echo "✅ РОЗГОРТАННЯ GRAFANA ЗАВЕРШЕНО!"
echo "=============================================="
echo ""
echo "Доступні сервіси:"
echo "  • Grafana UI:  http://192.168.100.30:3000"
echo ""
echo "Credentials (VULNERABLE - default):"
echo "  • Login:    admin"
echo "  • Password: admin"
echo ""
echo "⚠️  ВАЖЛИВО: При логіні НЕ змінюйте пароль!"
echo "   Grafana може попросити змінити пароль - просто закрийте це вікно"
echo "   або натисніть 'Skip' якщо доступно."
echo ""
echo "Datasource:"
echo "  • PostgreSQL: 192.168.20.20:5432 (citrine/citrine)"
echo ""
echo "CTF Info:"
echo "  • FLAG #5 знаходиться в описі дашборду 'EcoCharge CSMS Overview'"
echo "  • DB credentials витікають через description панелі 'System Notes'"
echo ""
echo "Troubleshooting:"
echo "  • Якщо все ще проблема з логіном:"
echo "    docker compose down -v    # Видалити ВСЕ включно з volume"
echo "    docker compose up -d      # Запустити заново"
echo ""
echo "  • Перегляд логів:"
echo "    docker compose logs -f grafana"
echo ""
echo "  • Перезапуск:"
echo "    docker compose restart grafana"
echo ""
