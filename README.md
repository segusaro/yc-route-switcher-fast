# Модуль route-switcher для обеспечения отказоустойчивости виртуальных машин, выполняющих функции межсетевого экранирования, сетевой безопасности и маршрутизации трафика 

## Содержание

- [Введение](#введение)
- [Возможности модуля](#возможности-модуля)
- [Компоненты модуля](#компоненты-модуля)
- [Входные параметры модуля](#входные-параметры-модуля)
- [Пример задания входных параметров модуля](#пример-задания-входных-параметров-модуля)
- [Выходные параметры модуля](#выходные-параметры-модуля)
- [Подготовка к развертыванию](#подготовка-к-развертыванию)
- [Порядок развертывания](#порядок-развертывания)
- [Проверка отказоустойчивости](#проверка-отказоустойчивости)
- [Остановка работы модуля](#остановка-работы-модуля)
- [Изменение входных параметров модуля](#изменение-входных-параметров-модуля)
- [Изменение маршрутов в таблицах маршрутизации](#изменение-маршрутов-в-таблицах-маршрутизации)
- [Мониторинг работы модуля](#мониторинг-работы-модуля)
- [Примеры использования модуля](#примеры-использования-модуля)


## Введение

В Yandex Cloud можно развернуть облачную инфраструктуру для защиты и сегментации инфраструктуры на зоны безопасности с использованием виртуальных машин (далее сетевых ВМ), выполняющих функции межсетевого экранирования, сетевой безопасности и маршрутизации трафика.
Каждый сегмент сети (далее сегмент) содержит ресурсы одного назначения, обособленные от других ресурсов. В облаке каждому сегменту может соответствовать свой каталог и своя облачная сеть VPC. В таком сценарии связь между сегментами обычно происходит через сетевые ВМ с несколькими сетевыми интерфейсами, размещенными в каждом VPC.

Для обеспечения высокой доступности развернутых приложений в такой инфраструктуре используется несколько сетевых ВМ, размещенных в разных зонах доступности.
С помощью [статической маршрутизации](https://cloud.yandex.ru/docs/vpc/concepts/static-routes) можно направлять трафик из подсетей через сетевые ВМ.

В облачной сети Yandex Cloud не поддерживается работа протоколов VRRP/HSRP между сетевыми ВМ.

Модуль route-switcher позволяет при отказе сетевой ВМ переключить на резервную ВМ:
- исходящий из сегмента трафика
- входящий в сегмент трафик через балансировщик нагрузки (опционально)


### Отказоустойчивость для исходящего из сегмента трафика

В примере на схеме VM-A и VM-B работают в режиме Active/Standby для исходящего трафика из сегмента.

<img src="./images/traffic_flows.png" alt="Прохождение трафика через сетевые ВМ для исходящего направления" width="500"/>

В случае отказа VM-A модуль route-switcher переключит исходящий трафик на VM-B и сетевая связанность с интернетом и между сегментами будет выполняться через VM-B.

<img src="./images/traffic_flows_failure.png" alt="Прохождение трафика через VM-B при отказе VM-A для исходящего направления" width="500"/>


### Отказоустойчивость для входящего в сегмент трафика

В примере на схеме VM-A и VM-B работают в режиме Active/Standby для входящего в сегмент трафика. Балансировщик нагрузки в сегменте public, целевыми ресурсами которого являются VM-A и VM-B, направляет трафик только на VM-A и при ее отказе направляет трафик на резервную VM-B. 

<img src="./images/traffic_flows_with_sg.png" alt="Прохождение трафика через сетевые ВМ для входящего направления" width="500"/>

Public интерфейсу VM-A назначены две группы безопасности: одна с правилами для работы необходимых сервисов, другая с правилами для прохождения [проверок доступности ресурсов](https://yandex.cloud/ru/docs/network-load-balancer/concepts/health-check) в сетевом балансировщике.
Public интерфейсу VM-B назначена одна группа безопасности с правилами для работы необходимых сервисов.

В случае отказа VM-A модуль route-switcher переключает группы безопасности между интерфейсами сетевых ВМ, обеспечивая успешное прохождение проверок состояний для VM-B и переключение входящего трафика на VM-B через балансировщик нагрузки. 

<img src="./images/traffic_flows_failure_with_sg.png" alt="Прохождение трафика через VM-B при отказе VM-A для входящего направления" width="500"/> 

В Yandex Cloud возможно развернуть два вида балансировщиков нагрузки:
- Сетевой балансировщик [Network Load Balancer](https://yandex.cloud/ru/docs/network-load-balancer/concepts/) с поддержкой протоколов TCP, UDP
- L7-балансировщик [Application Load Balancer](https://yandex.cloud/ru/docs/application-load-balancer/concepts/) с поддержкой протоколов HTTP/HTTPS, gRPC, TCP


> **Примечание**
> 
> 1. Если в сценарии использования сетевых ВМ не требуется обеспечить отказоустойчивость для входящего в сегмент трафика, переключение групп безопасности для сетевых ВМ не настраивается в параметрах модуля route-switcher.
> 
> 2. При использовании сетевого балансировщика Network Load Balancer учитывайте [особенности сходимости маршрутизации в зоне доступности](https://yandex.cloud/ru/docs/network-load-balancer/concepts/specifics#nlb-zone-converge). 


## Возможности модуля
- Переключение next hop адресов в таблицах маршрутизации при отказе сетевой ВМ на резервную ВМ  
- Возврат next hop адресов в таблицах маршрутизации на сетевую ВМ после ее восстановления (настраиваемая опция)
- Переключение групп безопасности между интерфейсами двух сетевых ВМ при отказе ВМ и восстановлении ВМ (настраиваемая опция) для обеспечения отказоустойчивости входящего трафика через балансировщики нагрузки
- Среднее время переключения next hop адресов в таблицах маршрутизации: 1 мин. Возможно уменьшение этого времени (см. [подробности](#алгоритм-работы-функции-route-switcher)).
- Среднее время переключения групп безопасности на интерфейсах сетевых ВМ: 1 мин. Возможно уменьшение этого времени (см. [подробности](#алгоритм-работы-функции-route-switcher)). 
- Работа с сетевыми ВМ, имеющими несколько сетевых интерфейсов в разных VPC
- Поддержка нескольких таблиц маршрутизации в разных VPC
- В качестве next hop в таблице маршрутизации можно указывать разные сетевые ВМ для разных префиксов
- Поддержка нескольких сетевых ВМ (минимум 2) для переключения next hop адресов
- Поддержка переключения групп безопасности для нескольких сетевых интерфейсов ВМ
- Указание TCP порта для проверки доступности сетевых ВМ
- Логирование работы модуля в Cloud Logging
- Мониторинг работы модуля с помощью метрик в Yandex Monitoring

## Обеспечение отказоустойчивости для входящего трафика

Модуль route-switcher позволяет переключать входящий в сегмент трафик при отказе сетевой ВМ на резервную ВМ. Балансировщик нагрузки, целевыми ресурсами которого являются сетевые ВМ, направляет трафик только на одну сетевую ВМ и при ее отказе направляет трафик на резервную ВМ. Модуль route-switcher переключает группы безопасности между интерфейсами сетевых ВМ в случае отказа и восстановления ВМ, обеспечивая успешное прохождение проверок состояний только у одной сетевой ВМ. Таким образом реализуется работа сетевых ВМ в режиме Active/Standby.

В примере на схеме VM-A и VM-B работают в режиме Active/Standby для входящего в сегмент трафика через сетевой балансировщик нагрузки в сегменте public.
Public интерфейс VM-A имеет две группы безопасности: одна содержит правила для работы необходимых сервисов, другая группа содержит правила для работы [проверок состояний](https://yandex.cloud/ru/docs/network-load-balancer/concepts/health-check) сетевого балансировщика.
Public интерфейс VM-B имеет одну группу безопасности с правилами для работы необходимых сервисов.

## Компоненты модуля

Модуль route-switcher создает следующие ресурсы, необходимые для его работы:
- Облачную функцию route-switcher
- NLB 
- Бакет в Object Storage 

<img src="./images/route-switcher.png" alt="Terraform модуль route-switcher" width="600"/>

Описание элементов схемы:

| Название элемента | Описание |
| ----------- | ----------- |
| Каталог: mgmt | Каталог для размещения компонент модуля route-switcher |
| VPC: mgmt | Сетевые интерфейсы ВМ, используемые для проверки их доступности, размещаются в подсетях этой сети. Обычно используется сегмент сети управления. |
| VM-A, VM-B | Сетевые ВМ, выполняющие функции межсетевого экранирования, сетевой безопасности и маршрутизации трафика, для которых требуется обеспечить отказоустойчивость |
| Функция route-switcher | Облачная функция, которая выполняет проверку состояния сетевых ВМ и в случае недоступности сетевых ВМ переключает next hop адреса в таблицах маршрутизации на резервные ВМ. Также функция возвращает next hop адреса в таблицах маршрутизации на сетевую ВМ после ее восстановления (возврат - это настраиваемая опция). | 
| NLB | Сетевой балансировщик для мониторинга доступности сетевых ВМ |
| Object Storage | Бакет в Object Storage для хранения файла конфигурации с информацией:<br>- таблицы маршрутизации с указанием предпочтительных next hop адресов для префиксов<br>- IP-адреса сетевых ВМ: для проверки доступности, адреса для каждого сетевого интерфейса ВМ (IP-адрес ВМ и соответствующий IP-адрес резервной ВМ) |


### Алгоритм работы функции route-switcher

Функция route-switcher вызывается по триггеру раз в минуту (значение по умолчанию), проверяет в каком состоянии находятся сетевые ВМ, и в случае недоступности сетевых ВМ переключает next hop адреса в таблицах маршрутизации. При восстановлении сетевой ВМ функция route-switcher возвращает ее next hop адреса в таблицах маршрутизации (если настроена такая опция).

Если заданы параметры для переключения групп безопасности на интерфейсах сетевых ВМ, то в случае недоступности сетевой ВМ происходит переключение групп безопасности между интефрейсами сетевых ВМ 

Возможно уменьшить интервал между последовательными проверками состояния сетевых ВМ во время работы облачной функции с помощью задания параметра `router_healthcheck_interval` во входных параметрах модуля. По умолчанию это значение 60 с. Если меняется значение по умолчанию, то рекомендуется дополнительно провести тестирование сценариев отказоустойчивости. Не рекомендуется устанавливать значение интервала менее 10 с.

![Алгоритм работы функции route-switcher](./images/route-switcher-alg.png)



## Входные параметры модуля

Перед вызовом модуля ему нужно передать набор входных параметров:

| Название | Описание | Тип | Значение по умолчанию | Обязательный |
| ----------- | ----------- | ----------- | ----------- | ----------- |
| `start_module` | Включить или выключить работу модуля (создает или удаляет триггер, запускающий облачную функцию route-switcher раз в минуту). Используется значение `true` для включения, `false` для выключения. | `bool` | `false` | да |
| `folder_id` | ID каталога для размещения компонент модуля route-switcher | `string` | `null` | да |
| `route_table_folder_list` | Список ID каталогов, в которых размещены таблицы маршрутизации из списка `route_table_list` | `list(string)` | `[]` | да |
| `route_table_list` | Список ID таблиц маршрутизации, для которых требуется переключение next hop адресов | `list(string)` | `[]` | да |
| `router_healthcheck_port` | TCP порт для проверки доступности сетевых ВМ. Этот порт на сетевой ВМ становится недоступным для подключения. |  `number` | `null` | да |
| `back_to_primary` | Включить или отключить возврат next hop адресов в таблицах маршрутизации на сетевую ВМ после ее восстановления. Включить или отключить возврат исходных групп безопасности на интерфейсах сетевой ВМ после ее восстановления. Используется значение `true` для включения, `false` для выключения. | `bool` | `true` | нет |
| `routers` | Список конфигураций сетевых ВМ. Смотрите [параметры routers](#параметр-routers). | `list(object)` | `[]` | да |
| `router_healthcheck_interval` | Интервал в секундах между последовательными проверками состояния сетевых ВМ во время работы облачной функции route-switcher. Значение интервала может быть не менее 10 с. Если меняется значение по умолчанию, то рекомендуется дополнительно провести тестирование сценариев отказоустойчивости.  | `number` | `60` | нет |
| `security_group_folder_list` | Список ID каталогов, в которых размещены группы безопасности в [параметре interfaces](#параметр-interfaces) | `list(string)` | `[]` | да, для переключения групп безопасности |

### Параметры `routers`

| Название | Описание | Тип | Значение по умолчанию | Обязательный |
| ----------- | ----------- | ----------- | ----------- | ----------- |
| `healthchecked_ip` | IP-адрес, используемый для проверки доступности сетевой ВМ | `string` | | да |
| `healthchecked_subnet_id` | подсеть для `healthchecked_ip` | `string` |  | да |
| `vm_id` | ID сетевой ВМ | `string` | | да, для переключения групп безопасности |
| `primary` | Является ли сетевая ВМ основной или резервной. Используется значение `true` для основной ВМ, `false` для резервной. `primary = true` может быть только у одной ВМ. | `bool` | `false` | да, для переключения групп безопасности |
| `interfaces` | Список интерфейсов сетевой ВМ. Смотрите [параметры interfaces](#параметр-interfaces). | `list(object)` | | да |

### Параметры `interfaces`:

| Название | Описание | Тип | Значение по умолчанию | Обязательный |
| ----------- | ----------- | ----------- | ----------- | ----------- |
| `own_ip` | IP-адрес интерфейса ВМ | `string` | | да, если IP-адрес интерфейса используется в качестве next hop адреса в таблице маршрутизации |
| `backup_peer_ip` | IP-адрес резервной ВМ для резервирования `own_ip` | `string` | | да, если IP-адрес интерфейса используется в качестве next hop адреса в таблице маршрутизации |
| `index` | Номер сетевого интерфейса ВМ, например `1` | `number` | | да, для переключения групп безопасности на интерфейсе |
| `security_group_ids` | Список ID групп безопасности, которые должны быть на интерфейсе ВМ в штатном режиме работы | `list(string)` | | да, для переключения групп безопасности на интерфейсе |


## Пример задания входных параметров модуля

Пример схемы с каталогами, таблицами маршрутизации и IP-адресами сетевых ВМ.

<img src="./images/example.png" alt="Пример схемы для входных параметров модуля" width="600"/>


<details>
<summary>Посмотреть пример задания входных параметров модуля с использованием строковых значений.</summary>

```yaml
module "route_switcher" {
  source    = "./modules/route-switcher/"
  start_module          = false
  folder_id = "b1g0000000000000mgmt" 
  route_table_folder_list = ["b1g00000000000000dmz"]
  route_table_list      = ["enp000000000000dmzrt"] 
  router_healthcheck_port = 22
  back_to_primary = true
  routers = [
    {
      healthchecked_ip = "192.168.1.10"
      healthchecked_subnet_id = "e9b000000000000mgmta"
      interfaces = [
        {
          own_ip = "10.160.1.10"
          backup_peer_ip = "10.160.2.10"
        }
      ]
    },
    {
      healthchecked_ip = "192.168.2.10"
      healthchecked_subnet_id = "e9b000000000000mgmtb"
      interfaces = [
        {
          own_ip = "10.160.2.10"
          backup_peer_ip = "10.160.1.10"
        }
      ]
    }
  ]
}
```

</details>

<details>
<summary>Посмотреть пример задания входных параметров модуля с использованием ресурсных объектов Terraform.</summary>

Если для развертывания сетевых ВМ, таблиц маршрутизации, подсетей и каталогов используется Terraform, то во входных параметрах модуля указываются ресурсные объекты Terraform.

```yaml
module "route_switcher" {
  source    = "./modules/route-switcher/"
  start_module          = false
  folder_id = var.folder_id
  route_table_folder_list = [yandex_resourcemanager_folder.dmz.id]
  route_table_list      = [yandex_vpc_route_table.dmz-rt.id]
  router_healthcheck_port = 22
  back_to_primary = true
  routers = [
    {
      healthchecked_ip = yandex_compute_instance.router-a.network_interface.1.ip_address
      healthchecked_subnet_id = yandex_vpc_subnet.mgmt_subnet_a.id
      interfaces = [
        {
          own_ip = yandex_compute_instance.router-a.network_interface.0.ip_address
          backup_peer_ip = yandex_compute_instance.router-b.network_interface.0.ip_address
        }
      ]
    },
    {
      healthchecked_ip = yandex_compute_instance.router-b.network_interface.1.ip_address
      healthchecked_subnet_id = yandex_vpc_subnet.mgmt_subnet_b.id
      interfaces = [
        {
          own_ip = yandex_compute_instance.router-b.network_interface.0.ip_address
          backup_peer_ip = yandex_compute_instance.router-a.network_interface.0.ip_address
        }
      ]
    }
  ]
}
```

</details>


### Пример задания входных параметров модуля для сценария переключения групп безопасности

Пример схемы с каталогами, таблицами маршрутизации, группами безопасности и IP-адресами сетевых ВМ.

<img src="./images/example-with-sg.png" alt="Пример схемы для входных параметров модуля для сценария переключения групп безопасности" width="700"/>

<details>
<summary>Посмотреть пример задания входных параметров модуля для сценария переключения групп безопасности на public сетевых интерфейсах ВМ и переключения next hop адресов в таблице маршрутизации dmz-rt.</summary>

```yaml
module "route_switcher" {
  source    = "./modules/route-switcher/"
  start_module          = false
  folder_id = "b1g00000000000000dmz" 
  route_table_folder_list = ["b1g00000000000000dmz"]
  route_table_list      = ["enp000000000000dmzrt"]
  security_group_folder_list = ["b1g00000000000000pub"] 
  router_healthcheck_port = 22
  back_to_primary = true
  routers = [
    {
      healthchecked_ip = "192.168.1.10"
      healthchecked_subnet_id = "e9b000000000000mgmta"
      primary = true
      vm_id = "fv400000000000000vma"
      interfaces = [
        {
          own_ip = "10.160.1.10"
          backup_peer_ip = "10.160.2.10"
        },
        {
          index = 1
          security_group_ids = ["enp000000000000sgpub", "enp000000000000sgnlb"]
        }
      ]
    },
    {
      healthchecked_ip = "192.168.2.10"
      healthchecked_subnet_id = "e9b000000000000mgmtb"
      vm_id = "epd00000000000000vmb"
      interfaces = [
        {
          own_ip = "10.160.2.10"
          backup_peer_ip = "10.160.1.10"
        },
        {
          index = 1
          security_group_ids = ["enp000000000000sgpub"]
        }
      ]
    }
  ]
}
```

</details>


## Выходные параметры модуля

| Название | Описание |
| ----------- | ----------- |
| `route-switcher_nlb` | Имя сетевого балансировщика в каталоге `folder_id` для мониторинга доступности сетевых ВМ |
| `route-switcher_bucket` | Имя бакета в Object Storage в каталоге `folder_id` для хранения файла конфигурации с информацией:<br>- таблицы маршрутизации с указанием предпочтительных next hop адресов для префиксов<br>- IP-адреса сетевых ВМ: для проверки доступности, адреса для каждого сетевого интерфейса ВМ (IP-адрес ВМ и соответствующий IP-адрес резервной ВМ) |
| `route-switcher_function` | Имя облачной функции в каталоге `folder_id`, обеспечивающей работу модуля route-switcher по отказоустойчивости исходящего трафика из сегментов |


## Подготовка к развертыванию

1. Перед развертыванием в Yandex Cloud должны существовать следующие объекты:
    - Каталог `folder_id` для размещения компонент модуля route-switcher
    - Таблицы маршрутизации, для которых требуется переключение next hop адресов
    - Каталоги, в которых размещены таблицы маршрутизации из списка `route_table_list`
    - Сетевые ВМ должны быть предварительно настроены, запущены и должны функционировать 

2. [Проверки состояния](https://cloud.yandex.ru/docs/network-load-balancer/concepts/health-check) сетевых ВМ осуществляются с IP-адресов из диапазонов `198.18.235.0/24` и `198.18.248.0/24`. Настройки правил фильтрации трафика у сетевых ВМ должны разрешать прием трафика с адресов этого диапазона, иначе проверки сетевым балансировщиком не будут выполняться и целевые ресурсы не перейдут в статус `Healthy`. В результате модуль route-switcher не сможет работать. Вы можете привязать к целевым ресурсам группу безопасности со следующим правилом для входящего трафика:
    - Диапазон портов: порт `router_healthcheck_port`, заданный во входных параметрах модуля route-switcher
    - Протокол: `TCP`
    - Источник: `Проверки состояния балансировщика`

    Такой же диапазон адресов и TCP порт должны быть настроены в разрешающем правиле для входящего трафика политики доступа в самих сетевых ВМ (например, в политике доступа межсетевых экранов).

3. Модуль записывает [логи работы функции](https://cloud.yandex.ru/docs/functions/operations/function/function-logs) в Cloud Logging группу по умолчанию в каталоге `folder_id`. Время хранения логов по умолчанию 3 дня. Можно [изменить срок хранения](https://cloud.yandex.ru/docs/logging/operations/retention-period) записей в группе Cloud Logging.


## Порядок развертывания

> **Важная информация**
> 
> Развертывать решение необходимо со значением `false` (значение по умолчанию) для входного параметра `start_module` модуля route-switcher.

1. Выполните инициализацию Terraform:
    ```bash
    terraform init
    ```

2. Проверьте конфигурацию Terraform файлов:
    ```bash
    terraform validate
    ```

3. Проверьте список создаваемых облачных ресурсов:
    ```bash
    terraform plan
    ```

4. Создайте ресурсы:
    ```bash
    terraform apply
    ```

5. После развертывания ресурсов убедитесь, что проверка состояния сетевых ВМ выдает значение `Healthy`. Для этого в консоли Yandex Cloud в каталоге `folder_id` выберите сервис `Network Load Balancer` и перейдите на страницу сетевого балансировщика `route-switcher-lb-...`. Раскройте целевую группу и убедитесь, что состояния целевых ресурсов `Healthy`. Если состояние их `Unhealthy`, то необходимо проверить, что сетевые ВМ запущены и функционируют, и проверить правила фильтрации трафика у сетевых ВМ (пункт 2. [подготовки к развертыванию](#подготовка-к-развертыванию)).

6. После того, как вы убедились, что проверка состояния сетевых ВМ выдает значение `Healthy`, измените значение входного параметра `start_module` модуля route-switcher на `true` для включения работы модуля и выполните команды:
    ```bash
    terraform plan
    terraform apply
    ```
7. После выполнения `terraform apply` с параметром `start_module = true` в каталоге `folder_id` создается триггер `route-switcher-trigger-...`, запускающий облачную функцию route-switcher раз в минуту. Триггер начинает работать в течение 5 минут после создания.

После выполнения всех шагов по развертыванию в сегментах будет осуществляться переключение исходящего трафика при отказе сетевой ВМ на резервную ВМ.

## Проверка отказоустойчивости

> **Важная информация**
> 
> Для проверки отказоустойчивости необходимо будет остановить сетевую ВМ, что приведет к временной недоступности сети в процессе переключения. В продуктивной среде необходимо согласовать технологическое окно для проведения проверки.

1. Выберите или создайте Linux ВМ в сегменте, для которого модуль route-switcher обеспечивает отказоустойчивость исходящего трафика. В консоли Yandex Cloud измените параметры этой ВМ, добавив "Разрешить доступ к серийной консоли". Подключитесь к серийной консоли ВМ и аутентифицируйтесь.

2. Запустите в этой ВМ исходящий трафик из сегмента с помощью `ping` к ресурсу в интернете или в другом сегменте.
    
3. В консоли Yandex Cloud выберите сетевую ВМ, через которую проходит исходящий трафик из сегмента, и остановите ее, эмулируя отказ.

4. Наблюдайте за пропаданием пакетов ping. После отказа сетевой ВМ может наблюдаться пропадание трафика, после чего трафик должен восстановиться.

5. Проверьте, что в таблице маршрутизации в каталоге сегмента используется адрес резервной ВМ для next hop.

6. В консоли Yandex Cloud запустите выключенную сетевую ВМ, эмулируя восстановление. 

7. Если в настройках модуля route-switcher был указан параметр `back_to_primary = true`, то после восстановления сетевой ВМ на нее произойдет переключение исходящего трафика. Может наблюдаться пропадание трафика, после чего трафик должен восстановиться. Проверьте, что в таблице маршрутизации в каталоге сегмента используется для next hop адрес сетевой ВМ из шага 3.

8. В консоли Yandex Cloud для Linux ВМ, с которой выполнялся `ping`, отключите "Разрешить доступ к серийной консоли".


## Остановка работы модуля

Если вы хотите временно остановить работу модуля route-switcher, то измените значение входного параметра `start_module` модуля route-switcher на `false` для выключения работы модуля и выполните команды:
```bash
terraform plan
terraform apply
```

После выполнения этих команд удалится триггер `route-switcher-trigger-...`, запускающий облачную функцию route-switcher раз в минуту, и работа модуля будет остановлена. 

Если вам потребуется включить работу модуля обратно, то выполните пункты 5 и 6 из раздела [Порядок развертывания](#порядок-развертывания).

## Изменение входных параметров модуля

В процессе работы модуля можно изменить входные параметры модуля. Например, во входных параметрах вы можете добавить или удалить IP-адреса сетевых ВМ или таблицы маршрутизации.

> **Важная информация**
> 
> Изменение входных параметров модуля необходимо выполнять при работающих сетевых ВМ. Убедитесь, что проверка состояния сетевых ВМ выдает значение `Healthy` (смотрите пункт 5 из раздела [Порядок развертывания](#порядок-развертывания)). 
> При добавлении таблиц маршрутизации модуль route-switcher сохранит текущие next hop адреса таблиц маршрутизации как предпочтительные в файле конфигурации в бакете Object Storage.

Для изменения входных параметров модуля выполните следующие действия:

1. Задайте входные параметры модуля.

2. Выполните команды:
    ```bash
    terraform plan
    terraform apply
    ```

## Изменение маршрутов в таблицах маршрутизации

В процессе работы модуля можно изменить next hop адреса сетевых ВМ в таблицах маршрутизации, указанных во входных параметрах модуля. Для этого необходимо выполнить следующие действия:

1. [Остановить работу модуля](#остановка-работы-модуля)

2. Изменить next hop адреса в таблицах маршрутизации

3. Включить работу модуля, выполнив пункты 5 и 6 из раздела [Порядок развертывания](#порядок-развертывания).

## Мониторинг работы модуля

Модуль поставляет метрики в [Yandex Monitoring](https://yandex.cloud/ru/docs/monitoring/):

| **Имя метрики** | **Описание** | **Возможные значения** | **Метки** |
| --- | --- | --- | --- |
| `route_switcher.switchover` | Необходимость переключения next hop в таблицах маршрутизации | `0` - переключение не требуется<br>`1` - необходимо переключение | `route_switcher_name` - имя функции route-switcher<br>`folder_name` - имя каталога с функцией route-switcher |
| `route_switcher.router_state` | Состояние доступности сетевой ВМ | `0` - недоступна<br>`1` - доступна | `router_ip` - IP-адрес сетевой ВМ<br>`folder_name` - имя каталога с функцией route-switcher |
| `route_switcher.table_changed` | Изменение next hop в таблице маршрутизации | `0` - отсутствуют изменения<br>`1` - выполнены изменения<br>`2` - возникла ошибка при выполнении изменений | `route_switcher_name` - имя функции route-switcher<br>`route_table_name` - имя таблицы маршрутизации<br>`folder_name` - имя каталога с функцией route-switcher |
| `route_switcher.security_groups_changed` | Изменение групп безопасности у интерфейса сетевой ВМ | `0` - отсутствуют изменения<br>`1` - выполнен запрос на изменение<br>`2` - возникла ошибка при выполнении изменений | `route_switcher_name` - имя функции route-switcher<br>`router_ip` - IP-адрес сетевой ВМ<br>`interface_index` - номер интерфейса сетевой ВМ<br>`folder_name` - имя каталога с функцией route-switcher |

- Метрики имеют значение `service=custom` (Custom Metrics, пользовательские метрики)  
- Для визуализации этих метрик можно [создать дашборд](https://yandex.cloud/ru/docs/monitoring/operations/dashboard/create)
- Пример [строки запроса](https://yandex.cloud/ru/docs/monitoring/concepts/visualization/query-string) для графика состояния доступности сетевых ВМ:
`"route_switcher.router_state"{folderId="<id каталога с функцией route-switcher>", service="custom", router_ip="*"} `
- С помощью [алертинга](https://yandex.cloud/ru/docs/monitoring/concepts/alerting) можно настроить уведомления об изменении метрик


## Примеры использования модуля

Вы можете познакомиться с двумя примерами использования модуля route-switcher:

1. [Решение по развертыванию защищенной высокодоступной сетевой инфраструктуры с выделением DMZ на основе Next-Generation Firewall](https://github.com/yandex-cloud-examples/yc-dmz-with-high-available-ngfw/)

2. [Решение по обеспечению отказоустойчивости NAT-инстанс](examples/README.md)