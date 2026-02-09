#!/bin/bash
# grafana-full-reset.sh - Повний перезапуск Grafana з очищенням

set -e

echo "=============================================="
echo "Grafana Full Reset & Restart"
echo "=============================================="
echo ""
echo "⚠️  WARNING: This will delete ALL Grafana data!"
echo "   - All dashboards (except provisioned)"
echo "   - All users (except admin)"
echo "   - All settings"
echo ""
read -p "Continue? (yes/no): " -r
if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    echo "Aborted."
    exit 1
fi

echo ""
echo "[1/8] Stopping Grafana..."
docker compose down
sleep 2

echo ""
echo "[2/8] Removing old volumes..."
docker volume rm grafana-deploy-fixed_grafana-data 2>/dev/null || true
docker volume rm grafana-deploy-fixed_grafana-logs 2>/dev/null || true
docker volume rm grafana-deploy_grafana-data 2>/dev/null || true
docker volume rm ecocharge-grafana_grafana-data 2>/dev/null || true
echo "✓ Volumes removed"

echo ""
echo "[3/8] Removing old container..."
docker rm -f ecocharge-grafana 2>/dev/null || true
echo "✓ Container removed"

echo ""
echo "[4/8] Checking files..."
for file in docker-compose.yml grafana.ini provisioning/datasources/datasources.yml; do
    if [ ! -f "$file" ]; then
        echo "❌ Missing: $file"
        exit 1
    fi
done
echo "✓ All files present"

echo ""
echo "[5/8] Creating fresh volumes..."
docker volume create grafana-deploy-fixed_grafana-data
docker volume create grafana-deploy-fixed_grafana-logs
echo "✓ Volumes created"

echo ""
echo "[6/8] Starting Grafana with new configuration..."
docker compose up -d

echo ""
echo "[7/8] Waiting for Grafana to be ready..."
for i in {1..30}; do
    if curl -sf http://localhost:3000/api/health >/dev/null 2>&1; then
        echo "✓ Grafana is ready!"
        break
    fi
    echo -n "."
    sleep 2
done
echo ""

echo ""
echo "[8/8] Testing login..."
sleep 3

# Test login
RESPONSE=$(curl -s -X POST http://localhost:3000/login \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "user=admin&password=admin" \
    -c /tmp/grafana_cookies.txt \
    -L -w "\n%{http_code}")

HTTP_CODE=$(echo "$RESPONSE" | tail -1)

if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "302" ]; then
    echo "✓ Login test passed (HTTP $HTTP_CODE)"
    
    # Try to access home
    HOME_RESPONSE=$(curl -s -b /tmp/grafana_cookies.txt http://localhost:3000/ -w "%{http_code}")
    HOME_CODE=$(echo "$HOME_RESPONSE" | tail -c 4)
    
    if [ "$HOME_CODE" = "200" ]; then
        echo "✓ Home page accessible!"
    else
        echo "⚠️  Home page returned: $HOME_CODE"
    fi
else
    echo "❌ Login test failed (HTTP $HTTP_CODE)"
fi

rm -f /tmp/grafana_cookies.txt

echo ""
echo "=============================================="
echo "Container status:"
echo "=============================================="
docker compose ps
echo ""

echo "=============================================="
echo "Recent logs:"
echo "=============================================="
docker compose logs --tail 20 grafana
echo ""

echo "=============================================="
echo "✅ GRAFANA RESET COMPLETE!"
echo "=============================================="
echo ""
echo "Access Grafana:"
echo "  URL: http://192.168.100.30:3000"
echo "  User: admin"
echo "  Pass: admin"
echo ""
echo "⚠️  IMPORTANT: If you still have issues:"
echo ""
echo "1. Clear browser cache and cookies"
echo "2. Try incognito/private mode"
echo "3. Try different browser"
echo "4. Check logs: docker compose logs -f grafana"
echo ""
echo "Troubleshooting commands:"
echo "  docker compose logs -f grafana     # Live logs"
echo "  docker exec -it ecocharge-grafana /bin/sh  # Shell access"
echo "  docker compose restart grafana     # Restart only"
echo ""
