# Changelog

## 0.1.3
- Добавлены const для BorderSide и Color.
- Проверка BuildContext.mounted теперь выполняется на том же контексте, который передаётся в showDialog.

## 0.1.2
- Исправлена const-ошибка в CardThemeData для Flutter 3.47.
- Убран лишний const у BorderSide.
- Добавлена проверка mounted непосредственно перед showDialog после асинхронных веток.

## 0.1.0 — Initial foundation
- Создан Flutter-каркас TimeControl.
- Добавлены пять разделов интерфейса.
- Подключена локальная SQLite.
- Реализованы базовое управление участниками, архив и мягкое удаление.
- Реализованы фактические отметки прихода/ухода и базовый обзор открытых сессий.
- Добавлены GitHub Actions workflow и документация.

## 0.1.1 — CI analyzer fixes
- Исправлен тип темы карточек для актуального Flutter API.
- Исправлены предупреждения const и async BuildContext.
- Удалён неиспользуемый импорт из smoke test.
