#!/bin/bash

set -e

# Проверяем наличие необходимых переменных окружения
if [ -z "$POSTGRES_USER" ] || [ -z "$POSTGRES_PASSWORD" ] || [ -z "$POSTGRES_DB" ]; then
    echo "Необходимо установить переменные окружения POSTGRES_USER, POSTGRES_PASSWORD и POSTGRES_DB"
    exit 1
fi

# Используем устаревшие переменные окружения, если они определены
PGUSER="${PGUSER:-$POSTGRES_USER}"
PGPASSWORD="${PGPASSWORD:-$POSTGRES_PASSWORD}"

# Обеспечиваем наличие переменной окружения PGPASSWORD
export PGPASSWORD="$POSTGRES_PASSWORD"

# Функция для инициализации базы данных
initialize_database() {
    # Создаем директорию для данных PostgreSQL
    mkdir -p "$PGDATA"
    chmod 700 "$PGDATA"

    # Инициализируем базу данных, если она еще не инициализирована
    if [ ! -f "$PGDATA/PG_VERSION" ]; then
        if [ -z "$REPLICATE_FROM" ]; then
            # Инициализация новой базы данных
            echo "Инициализация новой базы данных PostgreSQL"
            initdb -D "$PGDATA"
        else
            # Репликация из мастер-сервера
            echo "Репликация базы данных PostgreSQL из $REPLICATE_FROM"
            pg_basebackup -h "$REPLICATE_FROM" -P -D "$PGDATA"
        fi
    fi

    # Настраиваем файл pg_hba.conf
    echo "host all all 0.0.0.0/0 trust" >> "$PGDATA/pg_hba.conf"

    # Запускаем внутренний экземпляр PostgreSQL
    postgres -D "$PGDATA" &
    POSTGRES_PID=$!

    # Создаем пользователя и базу данных
    createuser -s "$PGUSER"
    createdb -O "$PGUSER" "$POSTGRES_DB"
}

# Функция для выполнения скриптов инициализации
run_initialization_scripts() {
    # Выполняем любые .sh, .sql или .sql.gz файлы в директории /docker-entrypoint-initdb.d/
    for f in /docker-entrypoint-initdb.d/*; do
        case "$f" in
            *.sh)
                echo "$0: выполнение $f"
                . "$f"
                ;;
            *.sql)
                echo "$0: выполнение $f"
                psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" < "$f"
                ;;
            *.sql.gz)
                echo "$0: выполнение $f"
                gunzip -c "$f" | psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB"
                ;;
            *)
                echo "$0: пропуск $f"
                ;;
        esac
    done
}

# Основная логика скрипта
initialize_database
run_initialization_scripts

# Если база данных была инициализирована (а не реплицирована), останавливаем внутренний экземпляр PostgreSQL
if [ -z "$REPLICATE_FROM" ]; then
    echo "Остановка внутреннего экземпляра PostgreSQL"
    pg_ctl -D "$PGDATA" stop
fi

echo "Инициализация PostgreSQL завершена"
