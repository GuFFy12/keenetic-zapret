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

- [Keenetic OS](https://help.keenetic.com/hc/ru/articles/115000990005) версии 4.0 или выше.
- Установленный [Entware](https://help.keenetic.com/hc/ru/articles/360021214160).

## Шаги установки

### 1. Настройки в веб-панели Keenetic

- В [компонентах KeeneticOS](https://help.keenetic.com/hc/ru/articles/360000358039) нужно включить `Kernel modules for Netfilter` или `Модули ядра подсистемы Netfilter`.

### 2. Установка необходимых компонентов

- Выполните следующую команду:

  ```sh
  opkg update && opkg install curl && curl -fL https://raw.githubusercontent.com/GuFFy12/keenetic-zapret/refs/heads/main/install.sh | sh
  ```

- Или если хотите установить в режиме оффлайн, то разархивируйте на роутере
  [файл релиз](https://github.com/GuFFy12/keenetic-zapret/releases/latest) и запустите:

  ```sh
  sh install.sh
  ```

### 3. Конфигурация Zapret ([`/opt/zapret/config`](https://github.com/bol-van/zapret))

- Переменная `IFACE_WAN` установлена автоматически на стандартный интерфейс `wan`, который использует внешний IP-адрес.
  Можно указать несколько сетей, тогда Zapret будет работать и для резервных подключений.
  Чтобы узнать его вручную, выполните команду:

  ```sh
  ip route show default 0.0.0.0/0
  ```

- Переменная `IFACE_LAN` установлена на стандартный интерфейс `lan` - `br0` (`192.168.1.0/24`), который по умолчанию стоит как домашняя сеть Keenetic.
  Можно указать несколько сетей или убрать переменную, что бы Zapret применялся для всех сегментов сетей.
  Чтобы узнать его вручную, выполните команду:

  ```sh
  ip route
  ```

- Чтобы отключить Zapret для группы устройств, создайте новый [сегмент сети](https://help.keenetic.com/hc/ru/articles/360005236300).
