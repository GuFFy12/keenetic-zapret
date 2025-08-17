# Keenetic Zapret

## Замечания

- Этот код создан для изучения сетевых технологий. Он может быть полезен для улучшения работы интернета, но то, как вы его используете — ваш выбор.
  Автор ответственности не несет.

- Конфигурация Zapret протестирована и работает стабильно. Со временем настройки могут стать неактуальными,
  проверяйте актуальные методы в репозитории и обсуждениях [Zapret](https://github.com/bol-van/zapret).

- Настройка `--dpi-desync-fooling=badsum` в Zapret может работать некорректно если роутер Keenetic находится за другим nat.
  Как пример таким устройством может быть оптический терминал который преобразует сигнал из оптоволокна.
  В этом случае данное устройство нужно перевести в режим моста (bridge).

## Требования

- [Keenetic OS](https://help.keenetic.com/hc/ru/articles/115000990005).
- Установленный [Entware](https://help.keenetic.com/hc/ru/articles/360021214160).

## Шаги установки

### 1. Настройки в веб-панели Keenetic

- В [компонентах KeeneticOS](https://help.keenetic.com/hc/ru/articles/360000358039) нужно включить `Kernel modules for Netfilter` или `Модули ядра подсистемы Netfilter`.

- Опционально отключите [DNS от провайдера](https://help.keenetic.com/hc/ru/articles/360008609399) и настройте [DNS-over-HTTPS](https://help.keenetic.com/hc/ru/articles/360007687159), например от Google: `https://dns.google/dns-query`.

### 2. Установка

- Скачайте [файл релиза](https://github.com/GuFFy12/keenetic-zapret/releases) формата `.ipk` прямо на роутере. Также можно скачать локально и переместить через [Менеджер USB-устройств](https://help.keenetic.com/hc/en-us/articles/360000799559).

- Установите пакет командой: `opkg install <ИМЯ_ФАЙЛА>`.

- Дальнейшие настройки осуществляются редактированием `/opt/zapret/config` файла и добавлением списков в файлы `/opt/zapret/ipset/*`.
