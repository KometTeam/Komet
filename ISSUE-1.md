# Перейти на монорепозиторий с использованием Pub workspaces

### Зачем?

### Пример

Ниже приведён вариант потенциальной структуры репозитория после подобной миграции:

- Если оставить корневой проект в качестве основного Flutter-приложения, и добавить периферийные пакеты:

  ```tree
  .
  ├── android/
  ├── ios/
  ├── linux/
  ├── macos/
  ├── windows/
  ├── ...
  ├── komet_ui/
  │   ├── lib/
  │   │   ├── src/
  │   │   └── komet_ui.dart
  │   ├── .gitignore
  │   └── pubspec.yaml
  ├── max_api/
  │   ├── lib/
  │   │   ├── src/
  │   │   └── max_api.dart
  │   ├── .gitignore
  │   └── pubspec.yaml
  ├── lib/
  │   └── main.dart
  ├── ...
  ├── .gitignore
  └── pubspec.yaml
  ```

### Мотивация

Инкапсуляция функций приложения (особенно тесно не связанных именно с Komet, например, MAX API):

- облегчит участие разработчиков в проекте;

- позволит

### См. также

- Pub workspaces (monorepo support):
  [dart.dev/tools/pub/workspaces](https://dart.dev/tools/pub/workspaces)
