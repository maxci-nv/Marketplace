### Установка Jenkins

1. Выполнить скрипт `install_jenkins.sh`:
  - при выполнении скрипта потребуется указать:
    -  директорию, в которой будут храниться файлы jenkins;
    -  порт на котором будет работать jenkins.
  - после установки будут отображены:
    - ссылка на jenkins;
    - initialAdminPassword - временный пароль администратора.
2. Открыть jenkins по ссылке.
3. Ввести временный пароль администратора.
4. Установить рекомендуемые плагины.
5. Создать администратора.

------------

##### Проверка установки

Открыть jenkins по ссылке: http://myserver:8088/ , где
- myserver -- ip или имя сервера
- 8088     -- порт

------------

### Добавление джобы в Jenkins

Для добавления джобы, которая будет периодически опращивать репозиторий git, и и выполнять pipeline из jenkinsfile, можно использовать скрипт `create-jenkins-job-git-pulling.sh`.

Скрипт запускается со следующими параметрами:
- `-repo`     -- ссылка на репозиторий Git.
- `-branch`   -- название ветки репозитория, которая будет опрашиваться.
- `-job`      -- название джобы, которая будет отображена в jenkins.
- `-schedule` -- расписание опроса репозитория в формате jenkins cron syntax.
- `-jenkins`  -- jenkins url.
- `-user`     -- логин администратора jenkins.
- `-pass`     -- пароль администратора jenkins.

Пример:
```bash
./create-jenkins-job-git-pulling.sh \
  -repo https://github.com/maxci-nv/Marketplace.git \
  -branch main \
  -job Marketplace_main \
  -schedule "H/2 * * * *" \
  -jenkins http://myserver:8088 \
  -user jenkins_admin \
  -pass jenkins_password
```