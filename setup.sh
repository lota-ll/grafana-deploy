#!/bin/bash
# ============================================================================
# EcoCharge Grafana Deployment Script
# Сервер: 192.168.100.30
# Datasource: PostgreSQL на 192.168.20.20:5432
# ============================================================================

set -e

echo "=============================================="
echo "EcoCharge Grafana Deployment"
echo "=============================================="

# --- 1. Docker ---
echo ""
echo "[1/5] Перевірка Docker..."
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

# --- 2. Перевірка зʼєднання з PostgreSQL ---
echo ""
echo "[2/5] Перевірка зʼєднання з CitrineOS PostgreSQL (192.168.20.20:5432)..."
if nc -zw3 192.168.20.20 5432 2>/dev/null; then
    echo "✅ PostgreSQL доступний"
else
    echo "⚠️  Не вдається зʼєднатися з PostgreSQL на 192.168.20.20:5432"
    echo "   Grafana запуститься, але дашборди не працюватимуть поки DB не стане доступною."
    read -p "   Продовжити все одно? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# --- 3. Перевірка файлів ---
echo ""
echo "[3/5] Перевірка файлів..."
MISSING=0
for file in docker-compose.yml provisioning/datasources/datasources.yml provisioning/dashboards/dashboards.yml dashboards/ecocharge-csms-overview.json; do
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

# --- 4. Firewall ---
echo ""
echo "[4/5] Налаштування iptables..."
# Дозволити Grafana UI з DMZ
sudo iptables -C INPUT -p tcp --dport 3000 -s 192.168.100.0/24 -j ACCEPT 2>/dev/null || \
    sudo iptables -A INPUT -p tcp --dport 3000 -s 192.168.100.0/24 -j ACCEPT

# Дозволити Grafana доступ до PostgreSQL (outbound)
sudo iptables -C OUTPUT -p tcp --dport 5432 -d 192.168.20.20 -j ACCEPT 2>/dev/null || \
    sudo iptables -A OUTPUT -p tcp --dport 5432 -d 192.168.20.20 -j ACCEPT

echo "✅ iptables налаштовано"

# --- 5. Запуск ---
echo ""
echo "[5/5] Запуск Grafana..."
docker compose up -d

# Очікування запуску
echo ""
echo "Очікування запуску Grafana..."
for i in $(seq 1 30); do
    if curl -sf http://localhost:3000/api/health > /dev/null 2>&1; then
        echo "✅ Grafana ready!"
        break
    fi
    sleep 2
    echo -n "."
done
echo ""

# --- Статус ---
echo ""
echo "=============================================="
echo "Статус контейнерів:"
echo "=============================================="
docker compose ps
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
echo "Datasource:"
echo "  • PostgreSQL: 192.168.20.20:5432 (citrine/citrine)"
echo ""
echo "CTF Info:"
echo "  • FLAG #5 знаходиться в описі дашборду 'EcoCharge CSMS Overview'"
echo "  • DB credentials витікають через description панелі 'System Notes'"
echo ""
echo "Корисні команди:"
echo "  docker compose logs -f        # Логи Grafana"
echo "  docker compose down            # Зупинити"
echo "  docker compose up -d           # Запустити"
echo ""
