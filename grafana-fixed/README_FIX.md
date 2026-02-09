# Grafana Login Problem - ULTIMATE FIX

## Проблема

**Симптом:**
- Логін з `admin:admin` → Skip password change → Редірект на `/login`
- Логи показують `status=302` (redirect)
- Сесія не зберігається

**Причина:**
Проблема з cookie/session management в Grafana. Це може бути через:
1. Некоректні session settings
2. Проблеми з permissions на `/var/lib/grafana`
3. Missing secret key
4. Cookie security settings

---

## Рішення (3 варіанти)

### 🔧 Варіант 1: Quick Fix (5 хвилин)

Якщо ви вже на Grafana VM:

```bash
# 1. Зупинити Grafana
cd /opt/ecocharge-grafana  # або ваша директорія
docker compose down

# 2. Видалити volume (ВАЖЛИВО!)
docker volume rm grafana-deploy-fixed_grafana-data -f
# або
docker volume ls | grep grafana  # Знайти назву
docker volume rm <назва_volume> -f

# 3. Запустити знову
docker compose up -d

# 4. Перевірити логи
docker compose logs -f grafana

# 5. Спробувати логін (через 30 секунд після запуску)
```

**Якщо не допомагає, перейдіть до Варіанту 2.**

---

### 🔧 Варіант 2: Використати виправлені файли (10 хвилин)

```bash
# 1. Завантажити виправлені файли на VM
# (Використайте файли з директорії grafana-fixed/)

# 2. На VM:
cd /opt/ecocharge-grafana

# Бекап старих файлів
cp docker-compose.yml docker-compose.yml.old
cp grafana.ini grafana.ini.old 2>/dev/null || true

# 3. Скопіювати нові файли
# (Замініть docker-compose.yml та grafana.ini новими версіями)

# 4. Запустити reset скрипт
chmod +x grafana-full-reset.sh
./grafana-full-reset.sh

# Скрипт автоматично:
# - Зупинить Grafana
# - Видалить всі volumes
# - Створить нові volumes
# - Запустить з новою конфігурацією
# - Протестує логін
```

---

### 🔧 Варіант 3: Manual Deep Fix (15 хвилин)

Якщо попередні варіанти не допомогли:

#### Крок 1: Діагностика

```bash
cd /opt/ecocharge-grafana

# Запустити діагностичний скрипт
chmod +x grafana-debug.sh
./grafana-debug.sh > grafana-diagnosis.txt

# Переглянути результат
cat grafana-diagnosis.txt
```

#### Крок 2: Повна зупинка

```bash
# Зупинити контейнер
docker compose down

# Видалити контейнер повністю
docker rm -f ecocharge-grafana

# Видалити ВСІ пов'язані volumes
docker volume ls | grep grafana
docker volume rm $(docker volume ls -q | grep grafana) -f

# Видалити образи (опціонально)
docker rmi grafana/grafana:10.4.2
```

#### Крок 3: Перевірити файли

```bash
# Переконатися що grafana.ini правильний
cat grafana.ini | grep -A 3 "\[session\]"

# Має бути:
# [session]
# provider = file
# provider_config = sessions
# cookie_secure = false
```

#### Крок 4: Створити volume вручну

```bash
# Створити volume з правильними permissions
docker volume create grafana-deploy-fixed_grafana-data

# Запустити тимчасовий контейнер для налаштування permissions
docker run --rm \
  -v grafana-deploy-fixed_grafana-data:/var/lib/grafana \
  busybox \
  sh -c "chmod 777 /var/lib/grafana"
```

#### Крок 5: Запустити з новими налаштуваннями

```bash
# Використати оновлений docker-compose.yml
docker compose up -d

# Моніторити логи
docker compose logs -f grafana
```

#### Крок 6: Тестування

```bash
# Дочекатися повного запуску (30-60 секунд)
sleep 30

# Тест 1: Health check
curl http://localhost:3000/api/health

# Тест 2: Login через API
curl -c /tmp/cookies.txt -X POST http://localhost:3000/login \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "user=admin&password=admin"

# Тест 3: Перевірити чи є cookies
cat /tmp/cookies.txt

# Тест 4: Спробувати доступ до home
curl -b /tmp/cookies.txt http://localhost:3000/

# Cleanup
rm /tmp/cookies.txt
```

---

## Додаткові перевірки

### Перевірка 1: Browser

```
⚠️  ВАЖЛИВО: Очистити browser cache!

Chrome/Edge:
  Ctrl+Shift+Delete → Cookies and cache → Clear

Firefox:
  Ctrl+Shift+Delete → Cookies → Clear

Safari:
  Preferences → Privacy → Manage Website Data → Remove All

Або спробувати Incognito/Private mode
```

### Перевірка 2: Network

```bash
# Перевірити чи Grafana слухає на правильному порті
netstat -tlnp | grep 3000

# Перевірити чи можна підключитися ззовні
curl -I http://192.168.100.30:3000

# Перевірити firewall
sudo iptables -L -n | grep 3000
```

### Перевірка 3: Permissions

```bash
# Перевірити permissions всередині контейнера
docker exec ecocharge-grafana ls -la /var/lib/grafana/

# Має бути щось схоже на:
# drwxr-xr-x  grafana.db
# drwxr-xr-x  sessions/

# Якщо permission denied, виправити:
docker exec ecocharge-grafana chown -R root:root /var/lib/grafana
docker compose restart grafana
```

---

## Що змінено в нових файлах

### docker-compose.yml:
```yaml
# ЗМІНИ:
user: "0:0"  # Run as root замість 472:472

# Додані environment variables:
GF_SECURITY_SECRET_KEY: "SW2YcwTIb9zpOOhoPsMm"
GF_SESSION_PROVIDER: "file"
GF_SESSION_COOKIE_SECURE: "false"
GF_SECURITY_COOKIE_SECURE: "false"
GF_SECURITY_COOKIE_SAMESITE: "lax"

# Додані volumes:
grafana-logs:/var/log/grafana
```

### grafana.ini:
```ini
# ЗМІНИ:
[session]
provider = file
provider_config = sessions
cookie_secure = false
session_life_time = 86400

[security]
cookie_secure = false
cookie_samesite = lax
```

---

## Troubleshooting

### Якщо все ще не працює:

#### Проблема: "Unauthorized" в логах

```bash
# Перевірити database
docker exec ecocharge-grafana sqlite3 /var/lib/grafana/grafana.db "SELECT * FROM user;"

# Якщо таблиця пуста або немає admin користувача:
docker exec ecocharge-grafana grafana-cli admin reset-admin-password admin
```

#### Проблема: Постійний редірект

```bash
# Видалити sessions
docker exec ecocharge-grafana rm -rf /var/lib/grafana/sessions/*
docker compose restart grafana
```

#### Проблема: "Database locked"

```bash
# Зупинити всі процеси Grafana
docker compose down
sleep 5
docker compose up -d
```

#### Проблема: Permissions

```bash
# Виправити всі permissions
docker exec ecocharge-grafana chown -R root:root /var/lib/grafana
docker exec ecocharge-grafana chmod -R 755 /var/lib/grafana
docker compose restart grafana
```

---

## Перевірка успішності

Якщо все працює правильно, ви побачите:

```bash
# 1. Health check успішний
$ curl http://localhost:3000/api/health
{"commit":"...","database":"ok","version":"10.4.2"}

# 2. Login працює
$ curl -c cookies.txt -X POST http://localhost:3000/login \
    -d "user=admin&password=admin"
# Результат: HTTP 200 або 302 з Set-Cookie

# 3. Cookies зберігаються
$ cat cookies.txt
# Має бути: grafana_session = ...

# 4. Home page доступна
$ curl -b cookies.txt http://localhost:3000/
# Результат: HTML з Grafana UI (не редірект на /login)
```

---

## Контакти підтримки

Якщо жодне рішення не допомогло:

1. Зберегти повні логи:
```bash
docker compose logs grafana > grafana-full-logs.txt
```

2. Зберегти діагностику:
```bash
./grafana-debug.sh > diagnosis.txt
```

3. Зберегти конфігурацію:
```bash
docker exec ecocharge-grafana cat /etc/grafana/grafana.ini > current-config.ini
```

4. Надіслати мені ці файли для аналізу.

---

## Альтернативне рішення (якщо нічого не допомагає)

Використати Grafana без docker-compose:

```bash
# Зупинити docker версію
docker compose down

# Запустити просту версію
docker run -d \
  --name grafana-simple \
  -p 3000:3000 \
  -e GF_SECURITY_ADMIN_USER=admin \
  -e GF_SECURITY_ADMIN_PASSWORD=admin \
  -e GF_AUTH_ANONYMOUS_ENABLED=false \
  grafana/grafana:10.4.2

# Перевірити
curl http://localhost:3000/api/health
```

Якщо це працює, значить проблема в docker-compose.yml або volumes.

---

**Дата:** 9 лютого 2026  
**Версія:** Ultimate Fix v1.0
