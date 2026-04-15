# PodlodkaPerfDemo - iOS Performance Demo App

Демо-приложение для доклада о производительности iOS приложений.

## Архитектура

### Структура проекта:
```
PodlodkaPerfDemo/
├── Models/
│   └── Article.swift              # CoreData модель статьи
├── CoreData/
│   └── CoreDataStack.swift        # Управление CoreData с signposts
├── Network/
│   └── NetworkService.swift       # Сетевой слой для загрузки данных
├── Repository/
│   └── ArticleRepository.swift    # Репозиторий для кэширования данных
└── Views/
    ├── Cells/
    │   └── ArticleTableViewCell.swift    # Ячейка tableView
    └── Controllers/
        ├── ArticlesListViewController.swift   # Главный экран (список)
        └── ArticleDetailViewController.swift  # Экран деталей
```

## Функционал

1. **Главный экран (ArticlesListViewController)**:
   - TableView с ячейками (картинка + текст с обрезкой)
   - Данные загружаются из сети (JSONPlaceholder + Picsum)
   - Кэширование в CoreData
   - Кнопка Refresh для перезагрузки данных

2. **Экран деталей (ArticleDetailViewController)**:
   - ScrollView с полной картинкой и текстом
   - Чтение данных из CoreData

## Signposts для мониторинга производительности

### Отслеживаемые события:

| Signpost Name | Описание |
|--------------|----------|
| `ScreenDisplay` | Время от появления экрана до скрытия |
| `DetailScreenDisplay` | Время отображения экрана деталей |
| `FetchArticles` | Время чтения из CoreData (список) |
| `FetchArticleDetail` | Время чтения из CoreData (детали) |
| `SaveArticle` | Время записи статьи в CoreData |
| `NetworkFetchArticles` | Время загрузки списка статей из сети |
| `NetworkDownloadImage` | Время загрузки картинки из сети |
| `LoadAndCacheArticles` | Общее время загрузки и кэширования |
| `ImageDecode` | Время декодирования картинки |
| `ContentLoaded` | Событие загрузки контента |

## Полезные ссылки

- [Instruments Tutorials](https://developer.apple.com/tutorials/instruments)
- [OSSignposter](https://developer.apple.com/documentation/os/ossignposter)
- [Доклад с Mobius](https://youtu.be/YxGfGGfgH6U?si=GnSlarLM9A8VcoIY)
- [Firefox Profiler](https://profiler.firefox.com/)
- [Firefox Gecko profile format](https://github.com/firefox-devtools/profiler/blob/main/docs-developer/gecko-profile-format.md)
