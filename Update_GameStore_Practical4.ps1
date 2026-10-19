#requires -Version 5.1
<#
Практическая работа №4: обновляет только lilqbite-svg/GameStore_Practical1.
Запуск: powershell -ExecutionPolicy Bypass -File .\Update_GameStore_Practical4.ps1
#>
param(
    [string]$ProjectDir = "",
    [switch]$NoPush,
    [switch]$SkipSuperuser
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$remoteUrl = "https://github.com/lilqbite-svg/GameStore_Practical1.git"

function Run-Checked {
    param([string]$Executable, [string[]]$Arguments)
    & $Executable @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Ошибка выполнения: $Executable $($Arguments -join ' ')"
    }
}

function Write-Utf8 {
    param([string]$Path, [string]$Content)
    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    $absolutePath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
    [System.IO.File]::WriteAllText($absolutePath, $Content.TrimStart([char[]]"`r`n").TrimEnd([char[]]"`r`n") + "`n", ([System.Text.UTF8Encoding]::new($false)))
}

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    throw "Git не найден. Установите Git for Windows."
}

if (-not $ProjectDir) {
    if (Test-Path (Join-Path (Get-Location) ".git")) {
        $ProjectDir = (Get-Location).Path
    } elseif (Test-Path (Join-Path (Get-Location) "GameStore_Practical1\.git")) {
        $ProjectDir = Join-Path (Get-Location) "GameStore_Practical1"
    } else {
        $ProjectDir = Join-Path (Get-Location) "GameStore_Practical1"
    }
}
$ProjectDir = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($ProjectDir)

if (-not (Test-Path (Join-Path $ProjectDir ".git"))) {
    Write-Host "Клонирование $remoteUrl ..." -ForegroundColor Cyan
    Run-Checked "git" @("clone", $remoteUrl, $ProjectDir)
}
Push-Location $ProjectDir
try {
    $origin = (& git remote get-url origin 2>$null) -join ""
    if ($LASTEXITCODE -ne 0 -or $origin -notmatch 'github\.com[:/]lilqbite-svg/GameStore_Practical1(?:\.git)?/?$') {
        throw "У папки другой origin. Чтобы не затронуть чужой проект, выполнение остановлено: $origin"
    }
    $dirty = @(git status --porcelain)
    # Если файл запуска положили в корень проекта, разрешаем только его самого.
    $otherChanges = @($dirty | Where-Object { $_ -notmatch '^\?\? Update_GameStore_Practical4\.ps1$' })
    if ($otherChanges.Count -gt 0) {
        throw "В репозитории есть незакоммиченные изменения. Сохраните их перед запуском:`n$($otherChanges -join "`n")"
    }

    Run-Checked "git" @("checkout", "main")
    Run-Checked "git" @("pull", "--ff-only", "origin", "main")
    foreach ($required in @("manage.py", "store/views.py", "store/templates/store/base.html", "store/templates/store/catalog.html")) {
        if (-not (Test-Path $required)) { throw "Не обнаружен файл проекта: $required" }
    }

    Write-Host "[1/6] Обновление моделей и админ-панели" -ForegroundColor Cyan
    Write-Utf8 "store/models.py" @'
from django.db import models


class Genre(models.Model):
    name = models.CharField("Название", max_length=80, unique=True)
    description = models.TextField("Описание", blank=True)
    is_active = models.BooleanField("Активен", default=True)

    class Meta:
        verbose_name = "жанр"
        verbose_name_plural = "жанры"
        ordering = ["name"]

    def __str__(self):
        return self.name


class Game(models.Model):
    title = models.CharField("Название", max_length=150, unique=True)
    genre = models.ForeignKey(Genre, on_delete=models.PROTECT, related_name="games", verbose_name="Жанр")
    price = models.PositiveIntegerField("Цена, ₽")
    description = models.TextField("Описание")
    image = models.CharField("Путь к изображению", max_length=200)
    available = models.BooleanField("В продаже", default=True)

    class Meta:
        verbose_name = "игра"
        verbose_name_plural = "игры"
        ordering = ["title"]

    def __str__(self):
        return self.title
'@

    Write-Utf8 "store/admin.py" @'
from django.contrib import admin
from .models import Game, Genre


@admin.register(Genre)
class GenreAdmin(admin.ModelAdmin):
    list_display = ("name", "is_active")
    list_filter = ("is_active",)
    search_fields = ("name", "description")


@admin.register(Game)
class GameAdmin(admin.ModelAdmin):
    list_display = ("title", "genre", "price", "available")
    list_filter = ("genre", "available")
    search_fields = ("title", "description", "genre__name")
    list_select_related = ("genre",)
'@

    Write-Utf8 "store/views.py" @'
from django.shortcuts import render
from .models import Game


def home(request):
    return render(request, "store/home.html")


def catalog(request):
    games = Game.objects.filter(available=True).select_related("genre")
    return render(request, "store/catalog.html", {"games": games})


def about(request):
    return render(request, "store/about.html")
'@

    Write-Host "[2/6] Обновление шаблонов и настройки локализации" -ForegroundColor Cyan
    $baseFile = "store/templates/store/base.html"
    $base = Get-Content -LiteralPath $baseFile -Raw -Encoding UTF8
    if ($base -notmatch 'admin:index') {
        if (-not $base.Contains("        </nav>")) { throw "Не найден закрывающий тег навигации в base.html" }
        $link = @'
            <a class="admin-nav-link" href="{% url 'admin:index' %}">Админ-панель</a>
'@
        $base = $base.Replace("        </nav>", $link + "`n        </nav>")
    }
    Write-Utf8 $baseFile $base

    $catalogFile = "store/templates/store/catalog.html"
    $catalog = Get-Content -LiteralPath $catalogFile -Raw -Encoding UTF8
    $catalog = $catalog.Replace("{{ game.genre }}", "{{ game.genre.name }}")
    if (-not $catalog.Contains("{{ game.price }} ₽")) {
        $catalog = $catalog.Replace("{{ game.price }}", "{{ game.price }} ₽")
    }
    Write-Utf8 $catalogFile $catalog

    $styleFile = "store/static/store/style.css"
    $style = Get-Content -LiteralPath $styleFile -Raw -Encoding UTF8
    if ($style -notmatch '\.admin-nav-link') {
        $style += "`n.navigation .admin-nav-link { background: var(--accent); color: white; }`n"
    }
    Write-Utf8 $styleFile $style

    $settingsFile = "config/settings.py"
    $settings = Get-Content -LiteralPath $settingsFile -Raw -Encoding UTF8
    if ($settings -match '(?m)^LANGUAGE_CODE\s*=') {
        $settings = [regex]::Replace($settings, '(?m)^LANGUAGE_CODE\s*=.*$', 'LANGUAGE_CODE = "ru-ru"')
    } else { $settings += "`nLANGUAGE_CODE = `"ru-ru`"`n" }
    if ($settings -match '(?m)^TIME_ZONE\s*=') {
        $settings = [regex]::Replace($settings, '(?m)^TIME_ZONE\s*=.*$', 'TIME_ZONE = "Europe/Moscow"')
    } else { $settings += "`nTIME_ZONE = `"Europe/Moscow`"`n" }
    Write-Utf8 $settingsFile $settings

    Write-Host "[3/6] Команда заполнения данных и тесты" -ForegroundColor Cyan
    Write-Utf8 "store/management/__init__.py" ""
    Write-Utf8 "store/management/commands/__init__.py" ""
    Write-Utf8 "store/management/commands/seed_gamestore.py" @'
from django.core.management.base import BaseCommand
from store.models import Game, Genre


GAMES = [
    ("Neon Drift", "Гонки", 1499, "Динамичные ночные заезды по улицам неонового мегаполиса.", "store/img/neon-drift.png"),
    ("Kingdom Forge", "RPG", 1999, "Приключенческая ролевая игра в большом фэнтезийном мире.", "store/img/kingdom-forge.png"),
    ("Deep Orbit", "Приключения", 2499, "Исследование далёкого космоса, планет и неизвестных станций.", "store/img/deep-orbit.png"),
    ("Iron Protocol", "Экшен", 1799, "Тактический экшен о специальном отряде в городе будущего.", "store/img/iron-protocol.png"),
    ("Green Valley", "Симулятор", 899, "Спокойный симулятор развития собственной фермы и поселения.", "store/img/green-valley.png"),
    ("Zero Signal", "Хоррор", 1299, "Мрачное приключение на заброшенном исследовательском комплексе.", "store/img/zero-signal.png"),
]


class Command(BaseCommand):
    help = "Добавить шесть игровых жанров и шесть игр (без дубликатов)."

    def handle(self, *args, **options):
        for title, genre_name, price, description, image in GAMES:
            genre, _ = Genre.objects.get_or_create(name=genre_name)
            Game.objects.get_or_create(
                title=title,
                defaults={
                    "genre": genre,
                    "price": price,
                    "description": description,
                    "image": image,
                },
            )
        self.stdout.write(self.style.SUCCESS(
            f"Готово: жанров {Genre.objects.count()}, игр {Game.objects.count()}"
        ))
'@

    Write-Utf8 "store/tests.py" @'
from django.contrib.auth import get_user_model
from django.core.management import call_command
from django.test import TestCase
from django.urls import reverse
from .models import Game, Genre


class PageTests(TestCase):
    def test_home_page(self):
        self.assertEqual(self.client.get(reverse("store:home")).status_code, 200)

    def test_catalog_page(self):
        self.assertEqual(self.client.get(reverse("store:catalog")).status_code, 200)

    def test_about_page(self):
        self.assertEqual(self.client.get(reverse("store:about")).status_code, 200)

    def test_catalog_displays_database_games(self):
        genre = Genre.objects.create(name="Тестовый жанр")
        Game.objects.create(title="Учебная игра", genre=genre, price=999,
                            description="Тестовый товар", image="store/img/neon-drift.png")
        response = self.client.get(reverse("store:catalog"))
        self.assertContains(response, "Учебная игра")
        self.assertContains(response, "999 ₽")

    def test_seed_is_idempotent(self):
        call_command("seed_gamestore", verbosity=0)
        call_command("seed_gamestore", verbosity=0)
        self.assertEqual(Genre.objects.count(), 6)
        self.assertEqual(Game.objects.count(), 6)


class AdminTests(TestCase):
    def setUp(self):
        user = get_user_model().objects.create_superuser(
            username="test_admin", email="admin@example.com", password="test_password_123"
        )
        self.client.force_login(user)

    def test_admin_index(self):
        self.assertEqual(self.client.get(reverse("admin:index")).status_code, 200)

    def test_games_admin_search_and_filter(self):
        genre = Genre.objects.create(name="Гонки")
        Game.objects.create(title="Neon Drift", genre=genre, price=1499,
                            description="Гоночная игра", image="store/img/neon-drift.png")
        url = reverse("admin:store_game_changelist")
        self.assertEqual(self.client.get(url).status_code, 200)
        self.assertContains(self.client.get(url, {"q": "Neon"}), "Neon Drift")
        self.assertEqual(self.client.get(url, {"genre__id__exact": genre.id}).status_code, 200)

    def test_genres_admin(self):
        self.assertEqual(self.client.get(reverse("admin:store_genre_changelist")).status_code, 200)
'@

    Write-Utf8 "REPORT_PRACTICAL4.md" @'
# Практическая работа №4 «Админ-панель»

**Дисциплина:** МДК 03.02 «Разработка кода информационных ресурсов»  
**Группа:** ВТ-1-24  
**Проект:** GameStore

## Цель
Подключить и настроить Django Admin для управления данными интернет-магазина компьютерных игр.

## Выполнение
1. В приложении `store` добавлены модели `Жанр` и `Игра`. В классе `Meta` каждой модели установлены русские `verbose_name` и `verbose_name_plural`; поля также подписаны по-русски.
2. В `config/settings.py` установлены `LANGUAGE_CODE = "ru-ru"` и `TIME_ZONE = "Europe/Moscow"`.
3. В `store/admin.py` обе модели зарегистрированы через `@admin.register`. Для каждой настроены `list_display`, `list_filter`, `search_fields`.
4. В таблице игр показываются название, жанр, цена и наличие: эти поля нужны для быстрого поиска и управления ассортиментом. Фильтры по жанру и наличию позволяют выбрать нужную категорию. Поиск работает по названию, описанию и жанру.
5. В таблице жанров отображаются название и активность: это позволяет управлять классификацией игр. Поиск настроен по названию и описанию, фильтр — по активности.
6. Добавлена команда `python manage.py seed_gamestore`, создающая шесть жанров и шесть игр без дублирования при повторном запуске.
7. Каталог теперь читает игры из базы данных. В шапку сайта добавлена ссылка «Админ-панель».
8. Суперпользователь создаётся локально командой `python manage.py createsuperuser`; база и пароли не публикуются на GitHub.

## Проверка
- `python manage.py check`
- `python manage.py makemigrations --check --dry-run`
- `python manage.py test`
- Перейти на `http://127.0.0.1:8000/admin/`, войти под суперпользователем и проверить записи, поиск и фильтры.

## Скриншоты для итогового отчёта
После запуска сайта добавить собственные снимки: главная страница админ-панели; список игр с фильтрами и поиском; список жанров; каталог и ссылка на админ-панель.

## Репозиторий
https://github.com/lilqbite-svg/GameStore_Practical1
'@

    $readmeFile = "README.md"
    $readme = Get-Content -LiteralPath $readmeFile -Raw -Encoding UTF8
    if ($readme -notmatch 'Практическая работа №4') {
        $readme += @'

## Практическая работа №4 «Админ-панель»

В текущий проект добавлены модели «Игры» и «Жанры», управление через Django Admin и русский интерфейс.

```powershell
py manage.py migrate
py manage.py seed_gamestore
py manage.py createsuperuser
py manage.py runserver
```

Админ-панель: http://127.0.0.1:8000/admin/ .

`db.sqlite3` и пароли не хранятся в Git. Команда `seed_gamestore` восстанавливает шесть игр и шесть жанров после клонирования. Детали: [отчёт №4](REPORT_PRACTICAL4.md).
'@
    }
    Write-Utf8 $readmeFile $readme

    Write-Host "[4/6] Python, миграции, тесты и начальные данные" -ForegroundColor Cyan
    if (-not (Test-Path ".venv\Scripts\python.exe")) {
        if (Get-Command py -ErrorAction SilentlyContinue) { $bootstrap = "py" }
        elseif (Get-Command python -ErrorAction SilentlyContinue) { $bootstrap = "python" }
        else { throw "Python не найден. Установите Python 3.12+ и повторите запуск." }
        if ($bootstrap -eq "py") { Run-Checked $bootstrap @("-3", "-m", "venv", ".venv") }
        else { Run-Checked $bootstrap @("-m", "venv", ".venv") }
    }
    $pythonExe = Join-Path $ProjectDir ".venv\Scripts\python.exe"
    Run-Checked $pythonExe @("-c", "import sys; assert sys.version_info >= (3, 12), 'Для Django 6.1 необходим Python 3.12 или новее'")
    Run-Checked $pythonExe @("-m", "pip", "install", "-r", "requirements.txt")
    Run-Checked $pythonExe @("manage.py", "check")
    Run-Checked $pythonExe @("manage.py", "makemigrations", "store", "--noinput")
    Run-Checked $pythonExe @("manage.py", "migrate", "--noinput")
    Run-Checked $pythonExe @("manage.py", "seed_gamestore")
    Run-Checked $pythonExe @("manage.py", "makemigrations", "--check", "--dry-run")
    Run-Checked $pythonExe @("manage.py", "test")

    Write-Host "[5/6] Суперпользователь" -ForegroundColor Cyan
    if (-not $SkipSuperuser) {
        $isAdmin = @(& $pythonExe "manage.py" "shell" "-c" "from django.contrib.auth import get_user_model; print(int(get_user_model().objects.filter(is_superuser=True).exists()))")
        if ($LASTEXITCODE -ne 0) { throw "Не удалось проверить суперпользователя" }
        if ($isAdmin.Count -eq 0 -or $isAdmin[-1].Trim() -eq "0") {
            Write-Host "Введите логин и пароль суперпользователя. Пароль не попадёт в Git." -ForegroundColor Yellow
            Run-Checked $pythonExe @("manage.py", "createsuperuser")
        } else {
            Write-Host "Суперпользователь уже существует."
        }
    } else {
        Write-Host "Создание суперпользователя пропущено по параметру -SkipSuperuser."
    }

    Write-Host "[6/6] Коммит и отправка в тот же репозиторий" -ForegroundColor Cyan
    # Копия скрипта также сохраняется в проекте для повторного использования.
    $targetScript = Join-Path $ProjectDir "Update_GameStore_Practical4.ps1"
    if ([System.IO.Path]::GetFullPath($PSCommandPath) -ne [System.IO.Path]::GetFullPath($targetScript)) {
        Copy-Item -LiteralPath $PSCommandPath -Destination $targetScript -Force
    }
    Run-Checked "git" @("add", "--", "Update_GameStore_Practical4.ps1", "README.md", "REPORT_PRACTICAL4.md", "config/settings.py", "store/models.py", "store/admin.py", "store/views.py", "store/tests.py", "store/management", "store/migrations", "store/templates/store/base.html", "store/templates/store/catalog.html", "store/static/store/style.css")
    & git diff --cached --quiet
    $diffExit = $LASTEXITCODE
    if ($diffExit -eq 1) {
        Run-Checked "git" @("commit", "-m", "Практическая работа №4: Django Admin для GameStore")
    } elseif ($diffExit -ne 0) {
        throw "Не удалось проверить индекс Git"
    } else {
        Write-Host "Изменений для коммита нет."
    }
    if (-not $NoPush) {
        if (Get-Command gh -ErrorAction SilentlyContinue) {
            & gh auth status --hostname github.com *> $null
            if ($LASTEXITCODE -ne 0) {
                Write-Host "Требуется вход в GitHub..." -ForegroundColor Yellow
                Run-Checked "gh" @("auth", "login", "--hostname", "github.com", "--git-protocol", "https", "--web")
            }
            Run-Checked "gh" @("auth", "setup-git")
        }
        Run-Checked "git" @("push", "origin", "main")
        $localHead = (& git rev-parse HEAD).Trim()
        if ($LASTEXITCODE -ne 0) { throw "Не удалось получить локальный коммит" }
        $remoteHead = (& git ls-remote origin refs/heads/main) -join ""
        if ($LASTEXITCODE -ne 0 -or -not $remoteHead.StartsWith($localHead)) {
            throw "Отправка завершилась, но не удалось подтвердить совпадение коммита с GitHub"
        }
        Write-Host "УСПЕШНО: изменения проверены на GitHub!" -ForegroundColor Green
        Write-Host "https://github.com/lilqbite-svg/GameStore_Practical1"
    } else {
        Write-Host "Локальный коммит готов; GitHub не обновлялся (-NoPush)." -ForegroundColor Yellow
    }
    Write-Host "Для просмотра сайта: .\.venv\Scripts\python.exe manage.py runserver"
    Write-Host "Админ-панель: http://127.0.0.1:8000/admin/"
} finally {
    Pop-Location
}
