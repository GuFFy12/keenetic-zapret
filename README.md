# Keenetic Zapret

## Замечания

- Этот код создан для изучения сетевых технологий. Он может быть полезен для улучшения работы интернета, но то, как вы его используете — ваш выбор.
  Автор ответственности не несет.

- Конфигурация Zapret протестирована и работает стабильно. Со временем настройки могут стать не актуальными,
  проверяйте актуальные методы в репозитории и обсуждениях [Zapret](https://github.com/bol-van/zapret).

- Настройка `--dpi-desync-fooling=badsum` в Zapret может работать не корректно если роутер Keenetic находится за другим nat.
  Как пример таким устройством может быть оптический терминал который преобразует сигнал из оптоволокна.
  В этом случае данное устройство нужно перевести в режим моста (bridge).

## Требования

- [Keenetic OS](https://help.keenetic.com/hc/ru/articles/115000990005).
- Установленный [Entware](https://help.keenetic.com/hc/ru/articles/360021214160).

## Шаги установки

### 1. Настройки в веб-панели Keenetic

- В [компонентах KeeneticOS](https://help.keenetic.com/hc/ru/articles/360000358039) нужно включить `Kernel modules for Netfilter` или `Модули ядра подсистемы Netfilter`.

- Опционально отключите [DNS от провайдера](https://help.keenetic.com/hc/ru/articles/360008609399) и настройте [DNS-over-HTTPS](https://help.keenetic.com/hc/ru/articles/360007687159), например от Google: `https://dns.google/dns-query`.

### 2. Установка необходимых компонентов

- Перед выполнением установки вы опционально можете настроить глобальные переменные которые находятся в начале [установочного файла](https://github.com/GuFFy12/keenetic-zapret/blob/main/install.sh).

- Для установки выполните следующую команду:

  ```sh
  opkg update && opkg install curl && curl -LsSf https://raw.githubusercontent.com/GuFFy12/keenetic-zapret/refs/heads/main/install.sh | sh
  ```

- Или если хотите установить в режиме оффлайн, то разархивируйте на роутере
  [файл релиз](https://github.com/GuFFy12/keenetic-zapret/releases/latest) и запустите:

  ```sh
  sh install.sh
  ```

- Для удаления выполните соответственно:

  ```sh
  curl -fL https://raw.githubusercontent.com/GuFFy12/keenetic-zapret/refs/heads/main/install.sh | sh -s uninstall
  ```

- Управление cronjob для регулярного обновления ipset list:

  ```sh
  curl -fL https://raw.githubusercontent.com/GuFFy12/keenetic-zapret/refs/heads/main/install.sh | sh -s <add-cronjob|remove-cronjob>
  ```
