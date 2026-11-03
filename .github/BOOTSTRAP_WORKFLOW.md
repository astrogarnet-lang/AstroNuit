# Важно: первичная установка workflow

GitHub не запускает workflow, который лежит только внутри ZIP, загружаемого в этот же репозиторий. Скопируйте `build-apk.yml` из архива в `.github/workflows/build-apk.yml` и сделайте первый commit. После этого можно загружать в корень репозитория только `TimeControl_Source.zip`.

В настройках репозитория проверьте: Settings → Actions → General → Workflow permissions → Read and write permissions. Это нужно, чтобы workflow мог удалить ZIP отдельным commit после успешной сборки.
