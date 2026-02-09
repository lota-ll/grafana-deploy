# EcoCharge Grafana Monitoring (FIXED) 🔧

**IP:** 192.168.100.30  
**OS:** Ubuntu 22.04  
**Роль:** Моніторинг інфраструктури EcoCharge. Містить FLAG #5.  
**FIX:** Виправлено проблему "Unauthorized" при логіні з admin:admin

---

## 🐛 Проблема яку виправлено

**Симптом:**
- Логін з admin:admin
- Grafana пропонує змінити пароль
- Залишаємо admin:admin (той самий)
- Отримуємо помилку "Unauthorized"

**Причина:**
Grafana за замовчуванням вимагає **реальної зміни** пароля при першому логіні. Навіть якщо ви вводите той самий пароль, Grafana це розпізнає і блокує.

**Рішення:**
Додано `grafana.ini` конфігурацію яка:
1. Відключає примусову зміну пароля
2. Дозволяє використовувати слабкі паролі (для CTF сценарію)
3. Налаштовує security settings для вразливості

---

## 📦 Що змінено

### 1. Новий файл: `grafana.ini`
```ini
[security]
admin_user = admin
admin_password = admin
password_min_length = 4
disable_brute_force_login_protection = true
```

### 2. Оновлений `docker-compose.yml`
- Додано volume mount для `grafana.ini`
- Видалено зайві environment змінні які конфліктували
- Додано `user: "472:472"` для правильних permissions

### 3. Оновлений `setup.sh`
- Додано очищення старого volume
- Додана перевірка connectivity до PostgreSQL
- Додано автоматичне тестування логіну
- Додані інструкції з troubleshooting

---

## 🚀 Розгортання

### Крок 1: Підготовка VM

```bash
# На Proxmox або іншій системі створіть VM:
# - OS: Ubuntu 22.04 Server
# - RAM: 2GB
# - CPU: 2 cores
# - Disk: 20GB
# - Network: vmbr_dmz (192.168.100.0/24)

# Налаштуйте IP адресу 192.168.100.30
sudo nano /etc/netplan/00-installer-config.yaml
```

```yaml
network:
  version: 2
  ethernets:
    eth0:  # або ens18
      addresses:
        - 192.168.100.30/24
      routes:
        - to: default
          via: 192.168.100.1
      nameservers:
        addresses:
          - 8.8.8.8
          - 1.1.1.1
```

```bash
sudo netplan apply
```

### Крок 2: Завантажити файли на VM

```bash
# З вашої робочої машини:
cd /path/to/grafana-deploy-fixed
tar czf grafana-deploy-fixed.tar.gz .
scp grafana-deploy-fixed.tar.gz user@192.168.100.30:/tmp/

# На VM:
ssh user@192.168.100.30
cd /opt
sudo mkdir -p ecocharge-grafana
sudo chown $USER:$USER ecocharge-grafana
cd ecocharge-grafana
tar xzf /tmp/grafana-deploy-fixed.tar.gz
```

### Крок 3: Запустити setup

```bash
cd /opt/ecocharge-grafana
sudo ./setup.sh
```

Скрипт виконає:
1. ✅ Перевірку Docker
2. ✅ Зупинку старого Grafana
3. ✅ Очищення старого volume (опціонально)
4. ✅ Перевірку connectivity до PostgreSQL
5. ✅ Запуск Grafana з новою конфігурацією
6. ✅ Тестування логіну

---

## 🔐 Вразливості

### 1. Default Credentials
**Вразливість:** `admin:admin` (не вимагає зміни)  
**Експлойт:** Прямий логін без брут-форсу  
**CTF Value:** Entry point для FLAGS #5 та #7

### 2. Information Disclosure
**Вразливість:** Dashboard description містить DB credentials  
**Локація:** Dashboard "EcoCharge CSMS Overview" → панель "System Notes"  
**Витік:**
```
DB Connection: postgresql://citrine:citrine@192.168.20.20:5432/citrine
Hasura Admin Secret: CitrineOS!
```

### 3. FLAG #5
**Локація:** Dashboard annotation або description  
**Значення:** `FLAG{d3f4ult_gr4f4n4_cr3ds_l34k}`

---

## 🧪 Тестування

### Перевірка 1: Web UI доступний

```bash
curl -I http://192.168.100.30:3000
# Очікується: HTTP/1.1 302 Found
```

### Перевірка 2: API здоров'я

```bash
curl http://192.168.100.30:3000/api/health
# Очікується: {"commit":"...","database":"ok","version":"10.4.2"}
```

### Перевірка 3: Логін працює

```bash
curl -X POST http://192.168.100.30:3000/api/login/ping \
     -u admin:admin
# Очікується: {"message":"Logged in"}
```

### Перевірка 4: Datasource підключений

```bash
# Відкрити браузер:
# http://192.168.100.30:3000
# Login: admin / Password: admin
# Перейти: Configuration → Data Sources → CitrineOS PostgreSQL
# Натиснути "Test" → має показати "Database Connection OK"
```

### Перевірка 5: Dashboard завантажується

```bash
# У браузері:
# Dashboards → Browse → EcoCharge CSMS Overview
# Має відобразитися dashboard з панелями
# Перевірити чи є FLAG в описі або annotation
```

---

## 🔍 Troubleshooting

### Проблема: Все ще "Unauthorized"

```bash
# Повне очищення та перезапуск:
cd /opt/ecocharge-grafana
docker compose down -v  # -v видаляє volumes!
docker compose up -d

# Перевірити логи:
docker compose logs -f grafana
```

### Проблема: PostgreSQL datasource не працює

```bash
# Перевірка connectivity з контейнера:
docker exec -it ecocharge-grafana /bin/sh
apk add postgresql-client netcat-openbsd
nc -zv 192.168.20.20 5432

# Якщо порт закритий - налаштувати firewall на CitrineOS (192.168.20.20):
sudo iptables -I INPUT 1 -p tcp -s 192.168.100.30 --dport 5432 -j ACCEPT
sudo iptables-save > /etc/iptables/rules.v4

# Або на firewall VM додати правило:
sudo iptables -I FORWARD 1 -s 192.168.100.30 -d 192.168.20.20 -p tcp --dport 5432 -j ACCEPT
```

### Проблема: Dashboard не показує дані

```bash
# Перевірити чи є дані в PostgreSQL:
docker exec -it citrine-postgres psql -U citrine -d citrine

SELECT COUNT(*) FROM "ChargingStation";
SELECT COUNT(*) FROM "Transaction";

# Якщо немає таблиць - CitrineOS не ініціалізувався
# Перевірити CitrineOS логи:
docker logs citrine-core
```

### Проблема: Grafana не стартує

```bash
# Перевірити порт 3000:
sudo netstat -tlnp | grep 3000

# Якщо зайнятий - знайти процес:
sudo lsof -i :3000

# Перевірити Docker:
docker ps -a
docker compose logs grafana
```

---

## 🎯 Attack Path (для CTF)

### Крок 1: Отримати доступ до Jump Host
```bash
# З Web Server (після RCE та PrivEsc):
cat /root/.ssh/id_jumphost  # FLAG #3
ssh -i id_jumphost operator@192.168.100.40  # FLAG #6
```

### Крок 2: SSH Tunnel до Grafana
```bash
# На Jump Host:
ssh -L 3000:192.168.100.30:3000 -N operator@192.168.100.40

# З Kali Linux (атакуючий):
ssh -i id_jumphost -L 3000:192.168.100.30:3000 operator@192.168.100.40

# Браузер на Kali:
http://localhost:3000
```

### Крок 3: Логін в Grafana
```
Username: admin
Password: admin
```

### Крок 4: Знайти FLAG #5
```
Dashboards → EcoCharge CSMS Overview → 
Перевірити description або annotations панелей
```

### Крок 5: Витягти DB credentials
```
Dashboard панель "System Notes" → Description:
postgresql://citrine:citrine@192.168.20.20:5432/citrine
```

### Крок 6: Підключитися до PostgreSQL
```bash
# З Jump Host:
psql -h 192.168.20.20 -U citrine -d citrine

# Знайти FLAG #7:
SELECT * FROM ctf_flags;
```

---

## 📋 Checklist

- [ ] VM створено з IP 192.168.100.30
- [ ] Docker встановлено
- [ ] Файли скопійовані в /opt/ecocharge-grafana
- [ ] setup.sh виконано успішно
- [ ] Grafana доступний на http://192.168.100.30:3000
- [ ] Логін admin:admin працює без "Unauthorized"
- [ ] PostgreSQL datasource підключений
- [ ] Dashboard завантажується
- [ ] FLAG #5 видимий
- [ ] DB credentials витікають в description

---

## 📞 Контакти та підтримка

Якщо виникають проблеми:
1. Перевірте логи: `docker compose logs -f grafana`
2. Перевірте connectivity: `nc -zv 192.168.20.20 5432`
3. Повне очищення: `docker compose down -v && docker compose up -d`

**Версія:** 1.0-fixed  
**Дата:** 9 лютого 2026  
