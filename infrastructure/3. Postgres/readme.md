### Установка PostgreSQL

1. Выполнить скрипт `install_postgres.sh`.
   - при выполнении скрипта потребуется указать:
     - директорию, в которой будут храниться файлы PostgreSQL;
     - порт, на котором будет работать PostgreSQL;
     - имя администратора PostgreSQL;
     - пароль администратора PostgreSQL.
   - во время установки скрипт:
     - выполнит первичную инициализацию PostgreSQL;
     - сгенерирует финальный `docker-compose.yml` без хранения пароля администратора;
   - после установки будут отображены:
     - директория установки;
     - имя контейнера;
     - имя администратора PostgreSQL;
     - порт подключения;
     - примеры подключения к серверу PostgreSQL.

------------

##### Проверка установки

Проверить, что контейнер запущен:

```bash
docker ps --filter "name=postgres"
```

Проверить состояние Healthcheck:

```bash
docker inspect postgres \
  --format='{{.State.Health.Status}}'
```

Ожидаемый результат:

```text
healthy
```

Подключение из контейнера:

```bash
docker exec -it postgres psql -U <admin_user> -d postgres
```

Подключение с хоста:

```bash
psql \
  -h myserver \
  -p 5432 \
  -U <admin_user> \
  -d postgres
```

где

- `myserver` — IP-адрес или имя сервера;
- `5432` — порт PostgreSQL;
- `<admin_user>` — имя администратора, указанное во время установки.
