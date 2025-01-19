# annotation 

# info 
Реализация заданий по предмету "Безопасность геоинформационных систем"

Стек используемый в проекте:
1. Python
2. Docker
3. Bash

# task
Создание отказоустойчивого кластера состоящего из следующих компонентов: 
1. pg_master - контейнер с бд psql в роли master
2. pg_slave - контейнер с бд psql в роли slave
3. pg_arbiter - веб сервер, который играет роль арбитра в кластере

# script
Агент на pg_slave проверяет досутпность pg_master, если pg_slave не получает ответ, то далее идет обращение к pg_arbiter для проверки состояния pg_master. Далее pg_arbiter делает запрос к pg_master, в случае если возращается ответ, что pg_master не функционирует, то pg_slave повышается до роли master, в ином случае ничего не происходит.
