# EcoCharge Grafana Monitoring (Vulnerable)

**IP:** 192.168.100.30
**OS:** Ubuntu 22.04
**Роль:** Моніторинг інфраструктури EcoCharge. Містить FLAG #5.

---

## Архітектура

- **Порт 3000:** Grafana Web UI
- **Datasource:** PostgreSQL (CitrineOS DB на 192.168.20.20:5432)
- **Вразливість:** Default credentials (admin:admin) + витік паролів БД у dashboard description

## Вразливості

1. **Default Credentials:** `admin:admin` (Grafana login)
2. **Info Disclosure:** Dashboard description містить credentials до PostgreSQL
3. **FLAG #5:** `FLAG{d3f4ult_gr4f4n4_cr3ds_l34k}` — в анотації дашборду

## Розгортання

```bash
sudo ./setup.sh
```

## Мережеві вимоги

| Напрямок | Порт | Протокол | Опис |
|----------|------|----------|------|
| Inbound (DMZ) | 3000 | TCP | Grafana UI |
| Outbound | 5432 | TCP | PostgreSQL до 192.168.20.20 |

## Attack Path

1. Атакуючий отримує доступ до Jump Host (192.168.100.40)
2. З Jump Host створює SSH tunnel: `ssh -L 3000:192.168.100.30:3000 ...`
3. Логін в Grafana: `admin:admin`
4. Знаходить FLAG #5 в описі дашборду
5. Знаходить credentials до PostgreSQL (citrine:citrine) в datasource description
