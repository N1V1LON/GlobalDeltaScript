# GlobalDeltaScript

Хаб **GlobalControler** для Delta executor (Roblox).  
Версия: **V26.1.2B** · язык UI: RU/EN · логика GS, GUI GM.

## Установка (одна строка)

В Delta → Execute:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/N1V1LON/GlobalDeltaScript/main/Install.lua"))()
```

Или без `Install.lua` — сразу контроллер:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/N1V1LON/GlobalDeltaScript/main/Scripts/GlobalControler.lua"))()
```

Нужен доступ к сети (`HttpGet`) и `loadstring`. Повторный запуск — синглтон, второй раз не пересоздаёт UI.

## Как это работает

- `Install.lua` качает **один** файл `Scripts/GlobalControler.lua` с raw GitHub и выполняет его.
- Внутри GC уже лежат все модули в `EMBEDDED` (16) — **без** отдельного клонирования репозитория на устройство.
- Если локально есть `Scripts/GlobalScripts` / `GlobalModules` / `Config.json` — GC подхватит их с диска (приоритет файлов), иначе embed.

## Данные — только на устройстве

| Что | Где | В GitHub? |
|-----|-----|-----------|
| `Config.json` (тема, язык, вкл. модули) | `writefile` → `…/Delta/Scripts/GlobalSystemFiles/Config.json` | **нет** (в репо только шаблон-дефолт) |
| Профили игр `Profiles/<placeId>.json` | `…/GlobalSystemFiles/Profiles/` | **нет** (`.gitignore`) |
| Точки TP, quick-toggle | внутри Config на диске | **нет** |

Личные настройки и прогресс **не** попадают в репозиторий: GC пишет только через `writefile` на телефон/ПК.  
Не коммитите свой живой `Config.json` и `Profiles/` — иначе их увидят/поправят все.

## Пути (локально vs raw GitHub)

GC ищет Base по кандидатам (первое совпадение):

1. `/storage/emulated/0/Delta/Scripts/`
2. `/sdcard/Delta/Scripts/`
3. `Scripts/`
4. `./Scripts/`
5. `""` (без Base — режим embed, статус: Base не найден, модули всё равно грузятся)

| Режим | Откуда код | Config / Profiles |
|-------|------------|-------------------|
| **loadstring с GitHub** | raw URL → один `GlobalControler.lua` | defaults + writefile на устройство (если Base найден) |
| **клон репо в Delta/Scripts** | файлы на диске | тот же Config на диске |
| **только embed** | EMBEDDED внутри GC | defaults; save — если create/writefile доступны |

Сырой URL всегда ветка `main`:

```text
https://raw.githubusercontent.com/N1V1LON/GlobalDeltaScript/main/Scripts/GlobalControler.lua
```

Если ветка/имя репо изменится — сломается `Install.lua` (одна константа `RAW`).

## Структура

```text
Install.lua                 — bootstrap (HttpGet + loadstring)
Scripts/GlobalControler.lua — entrypoint + EMBEDDED всех модулей
Scripts/GlobalScripts/      — GS: логика (без GUI)
Scripts/GlobalModules/      — GM: GUI (без логики)
Scripts/GlobalSystemFiles/  — Config.json (шаблон), docs, Profiles/ (не в git)
```

Вкладки: **Player** · **Server** · **Settings**.  
Карточки: Speed, TP, NoClip, Jump, FastHeal · Spoofing, Players · Интерфейс.

## Контракт модуля (кратко)

Одна таблица, `return` + `env[ИмяФайла]`: `GetTable`, `GetPosition`, `Name`, `Desc`, `Open(config)`; опц. `QuickToggle` + `IsOn`/`SetOn`/`Restore`.  
Подробности: `Scripts/GlobalSystemFiles/DocProjectGlobal.md`.

## Документы

- `Scripts/GlobalSystemFiles/DocProjectGlobal.md` — спека проекта  
- `Scripts/GlobalSystemFiles/TODO.md` — задачи  
- `Scripts/GlobalSystemFiles/DESIGN.md`, `DESIGN-GC-Hub.md` — дизайн  
- `AGENTS.md` — правила репозитория  

## Лицензия / воркфлоу

Ветка `main`. Коммиты: `Vyy.y.zR|D|B|P: <текст>` по-русски.  
Версия: `год.release.patch` + `R`/`P`/`B`/`D`.
