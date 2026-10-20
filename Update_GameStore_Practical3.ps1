#requires -Version 5.1
<#
Практическая работа №3. Продолжает существующий GameStore_Practical1, сохраняет №4.
Запуск из PowerShell:
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\Downloads\Update_GameStore_Practical3.ps1"
#>
param(
    [string]$ProjectDir = "",
    [switch]$NoPush
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$remoteUrl = "https://github.com/lilqbite-svg/GameStore_Practical1.git"

function Run-Checked {
    param([string]$Executable, [string[]]$Arguments)
    & $Executable @Arguments
    if ($LASTEXITCODE -ne 0) { throw "Ошибка выполнения: $Executable $($Arguments -join ' ')" }
}

function Write-Utf8 {
    param([string]$Path, [string]$Content)
    $folder = Split-Path -Parent $Path
    if ($folder -and -not (Test-Path -LiteralPath $folder)) {
        New-Item -ItemType Directory -Path $folder -Force | Out-Null
    }
    $abs = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
    [System.IO.File]::WriteAllText($abs, ($Content.TrimEnd([char[]]"`r`n") + "`n"), ([System.Text.UTF8Encoding]::new($false)))
}

if (-not (Get-Command git -ErrorAction SilentlyContinue)) { throw "Не найден git.exe" }
if (-not $ProjectDir) {
    $ProjectDir = Join-Path $env:USERPROFILE "GameStore_Practical1"
}
$ProjectDir = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($ProjectDir)
if (-not (Test-Path (Join-Path $ProjectDir ".git"))) {
    if (Test-Path $ProjectDir) { throw "Папка существует, но это не git-репозиторий: $ProjectDir" }
    Run-Checked "git" @("clone", $remoteUrl, $ProjectDir)
}
Push-Location $ProjectDir
try {
    $origin = (& git remote get-url origin 2>$null) -join ""
    if ($LASTEXITCODE -ne 0 -or $origin -notmatch 'github\.com[:/]lilqbite-svg/GameStore_Practical1(?:\.git)?/?$') {
        throw "Неожиданный адрес Git origin: $origin"
    }
    $dirty = @(git status --porcelain)
    # Разрешён только скачанный скрипт, если он оказался в корне репозитория.
    $otherChanges = @($dirty | Where-Object { $_ -notmatch '^\?\? Update_GameStore_Practical3\.ps1$' })
    if ($otherChanges.Count -gt 0) {
        throw "В репозитории есть другие несохранённые изменения. Сначала сохраните их:`n$($otherChanges -join "`n")"
    }
    Run-Checked "git" @("checkout", "main")
    Run-Checked "git" @("pull", "--ff-only", "origin", "main")
    foreach ($file in @("manage.py", "store/models.py", "store/admin.py", "store/views.py", "store/urls.py")) {
        if (-not (Test-Path $file)) { throw "Не найден нужный файл: $file" }
    }
    Write-Host "[1/6] Добавление моделей и связей (с сохранением практической №4)" -ForegroundColor Cyan
    $modelPath = "store/models.py"
    $models = Get-Content -LiteralPath $modelPath -Raw -Encoding UTF8
    if ($models -notmatch 'class Developer\(') {
        $old = '    available = models.BooleanField("В продаже", default=True)'
        if (-not $models.Contains($old)) { throw "Не найдено поле Game.available, структура моделей изменилась." }
        $new = $old + "`n" + '    developer = models.ForeignKey("Developer", on_delete=models.PROTECT, null=True, blank=True, related_name="games", verbose_name="Разработчик")' + "`n" + '    tags = models.ManyToManyField("Tag", blank=True, related_name="games", verbose_name="Метки")'
        $models = $models.Replace($old, $new)
        $models = $models.TrimEnd() + "`n`n`n" + @'
class Developer(models.Model):
    name = models.CharField("Название", max_length=120, unique=True)
    country = models.CharField("Страна", max_length=80)
    website = models.URLField("Сайт", blank=True)

    class Meta:
        verbose_name = "разработчик"
        verbose_name_plural = "разработчики"
        ordering = ["name"]

    def __str__(self):
        return self.name


class Tag(models.Model):
    name = models.CharField("Название", max_length=60, unique=True)

    class Meta:
        verbose_name = "метка"
        verbose_name_plural = "метки"
        ordering = ["name"]

    def __str__(self):
        return self.name


class GameDetail(models.Model):
    game = models.OneToOneField(Game, on_delete=models.CASCADE, related_name="details", verbose_name="Игра")
    release_year = models.PositiveSmallIntegerField("Год выпуска")
    platform = models.CharField("Платформа", max_length=80)
    age_rating = models.CharField("Возрастной рейтинг", max_length=10)

    class Meta:
        verbose_name = "информация об игре"
        verbose_name_plural = "информация об играх"
        ordering = ["game__title"]

    def __str__(self):
        return f"{self.game.title} ({self.release_year})"
'@
        Write-Utf8 $modelPath $models
    }

    $adminPath = "store/admin.py"
    $admin = Get-Content -LiteralPath $adminPath -Raw -Encoding UTF8
    if ($admin -notmatch 'class DeveloperAdmin\(') {
        $old = 'from .models import Game, Genre'
        if (-not $admin.Contains($old)) { throw "Неожиданный импорт моделей в admin.py" }
        $admin = $admin.Replace($old, 'from .models import Developer, Game, GameDetail, Genre, Tag')
        $admin = $admin.TrimEnd() + "`n`n" + @'
@admin.register(Developer)
class DeveloperAdmin(admin.ModelAdmin):
    list_display = ("name", "country", "website")
    list_filter = ("country",)
    search_fields = ("name", "country")


@admin.register(Tag)
class TagAdmin(admin.ModelAdmin):
    list_display = ("name",)
    search_fields = ("name",)


@admin.register(GameDetail)
class GameDetailAdmin(admin.ModelAdmin):
    list_display = ("game", "release_year", "platform", "age_rating")
    list_filter = ("release_year", "platform")
    search_fields = ("game__title", "platform")
'@
        Write-Utf8 $adminPath $admin
    }

    Write-Host "[2/6] Формы, страницы пяти таблиц и CSRF" -ForegroundColor Cyan
    Write-Utf8 "store/forms.py" @'
from datetime import date
from django import forms
from .models import Developer, Game, GameDetail, Genre, Tag


class GenreForm(forms.ModelForm):
    class Meta:
        model = Genre
        fields = ["name", "description", "is_active"]


class DeveloperForm(forms.ModelForm):
    class Meta:
        model = Developer
        fields = ["name", "country", "website"]


class TagForm(forms.ModelForm):
    class Meta:
        model = Tag
        fields = ["name"]


class GameForm(forms.ModelForm):
    class Meta:
        model = Game
        fields = ["title", "genre", "developer", "price", "description", "image", "tags", "available"]
        widgets = {"description": forms.Textarea(attrs={"rows": 3})}

    def clean_price(self):
        price = self.cleaned_data["price"]
        if price <= 0:
            raise forms.ValidationError("Цена должна быть больше нуля.")
        return price


class GameDetailForm(forms.ModelForm):
    class Meta:
        model = GameDetail
        fields = ["game", "release_year", "platform", "age_rating"]

    def clean_release_year(self):
        year = self.cleaned_data["release_year"]
        if year < 1980 or year > date.today().year:
            raise forms.ValidationError("Укажите год с 1980 по текущий год.")
        return year
'@
    Write-Utf8 "store/templates/store/db_details.html" @'
{% extends 'store/db_page_base.html' %}
{% block records %}
<table class="database-table"><thead><tr><th>ID</th><th>Игра</th><th>Год выпуска</th><th>Платформа</th><th>Возрастной рейтинг</th></tr></thead><tbody>
{% for item in items %}<tr><td>{{ item.id }}</td><td>{{ item.game.title }}</td><td>{{ item.release_year }}</td><td>{{ item.platform }}</td><td>{{ item.age_rating }}</td></tr>
{% empty %}<tr><td colspan="5">Записей пока нет.</td></tr>{% endfor %}
</tbody></table>
{% endblock %}
'@
    Write-Utf8 "store/templates/store/db_developers.html" @'
{% extends 'store/db_page_base.html' %}
{% block records %}
<table class="database-table"><thead><tr><th>ID</th><th>Название</th><th>Страна</th><th>Сайт</th></tr></thead><tbody>
{% for item in items %}<tr><td>{{ item.id }}</td><td>{{ item.name }}</td><td>{{ item.country }}</td><td>{{ item.website|default:'—' }}</td></tr>
{% empty %}<tr><td colspan="4">Записей пока нет.</td></tr>{% endfor %}
</tbody></table>
{% endblock %}
'@
    Write-Utf8 "store/templates/store/db_games.html" @'
{% extends 'store/db_page_base.html' %}
{% block records %}
<table class="database-table"><thead><tr><th>ID</th><th>Название</th><th>Жанр</th><th>Разработчик</th><th>Цена, ₽</th><th>Метки</th><th>В продаже</th></tr></thead><tbody>
{% for item in items %}<tr><td>{{ item.id }}</td><td>{{ item.title }}</td><td>{{ item.genre.name }}</td><td>{{ item.developer.name|default:'—' }}</td><td>{{ item.price }}</td><td>{% for tag in item.tags.all %}{{ tag.name }}{% if not forloop.last %}, {% endif %}{% empty %}—{% endfor %}</td><td>{{ item.available|yesno:'Да,Нет' }}</td></tr>
{% empty %}<tr><td colspan="7">Записей пока нет.</td></tr>{% endfor %}
</tbody></table>
{% endblock %}
'@
    Write-Utf8 "store/templates/store/db_genres.html" @'
{% extends 'store/db_page_base.html' %}
{% block records %}
<table class="database-table"><thead><tr><th>ID</th><th>Название</th><th>Описание</th><th>Активен</th></tr></thead><tbody>
{% for item in items %}<tr><td>{{ item.id }}</td><td>{{ item.name }}</td><td>{{ item.description|default:'—' }}</td><td>{{ item.is_active|yesno:'Да,Нет' }}</td></tr>
{% empty %}<tr><td colspan="4">Записей пока нет.</td></tr>{% endfor %}
</tbody></table>
{% endblock %}
'@
    Write-Utf8 "store/templates/store/db_index.html" @'
{% extends 'store/base.html' %}
{% block title %}Таблицы базы данных — GameStore{% endblock %}
{% block content %}
<section class="page-hero"><div class="container"><h1>База данных GameStore</h1><p>Выберите таблицу для просмотра и добавления записей.</p></div></section>
<section class="database-section"><div class="container database-links">
  <a href="{% url 'store:database_genres' %}">Жанры</a>
  <a href="{% url 'store:database_games' %}">Игры</a>
  <a href="{% url 'store:database_developers' %}">Разработчики</a>
  <a href="{% url 'store:database_details' %}">Информация об играх</a>
  <a href="{% url 'store:database_tags' %}">Метки</a>
</div></section>
{% endblock %}
'@
    Write-Utf8 "store/templates/store/db_page_base.html" @'
{% extends 'store/base.html' %}
{% block title %}{{ page_title }} — GameStore{% endblock %}
{% block content %}
<section class="page-hero"><div class="container"><h1>{{ page_title }}</h1><p>Практическая работа №3: добавление и просмотр записей из базы данных.</p></div></section>
<section class="database-section"><div class="container">
  <p class="database-back"><a href="{% url 'store:database_index' %}">← Ко всем таблицам</a></p>
  {% if messages %}{% for message in messages %}<p class="database-success" role="status">{{ message }}</p>{% endfor %}{% endif %}
  <div class="database-panel">
    <h2>Добавить запись</h2>
    <form method="post" novalidate>
      {% csrf_token %}
      {{ form.non_field_errors }}
      {% for field in form %}
        <div class="database-field">
          <label for="{{ field.id_for_label }}">{{ field.label }}{% if field.field.required %} *{% endif %}</label>
          {{ field }}
          {% if field.help_text %}<small>{{ field.help_text }}</small>{% endif %}
          {% for error in field.errors %}<p class="database-error" role="alert">{{ error }}</p>{% endfor %}
        </div>
      {% endfor %}
      <button class="database-submit" type="submit">Сохранить</button>
    </form>
  </div>
  <div class="database-panel"><h2>Список записей</h2><div class="database-table-wrap">{% block records %}{% endblock %}</div></div>
</div></section>
{% endblock %}
'@
    Write-Utf8 "store/templates/store/db_tags.html" @'
{% extends 'store/db_page_base.html' %}
{% block records %}
<table class="database-table"><thead><tr><th>ID</th><th>Название</th></tr></thead><tbody>
{% for item in items %}<tr><td>{{ item.id }}</td><td>{{ item.name }}</td></tr>
{% empty %}<tr><td colspan="2">Записей пока нет.</td></tr>{% endfor %}
</tbody></table>
{% endblock %}
'@

    $viewsPath = "store/views.py"
    $views = Get-Content -LiteralPath $viewsPath -Raw -Encoding UTF8
    if ($views -notmatch 'def database_index\(') {
        $origImport = 'from django.shortcuts import render'
        if (-not $views.Contains($origImport)) { throw "Не найден импорт render в views.py" }
        $views = $views.Replace($origImport, 'from django.contrib import messages' + "`n" + 'from django.shortcuts import redirect, render' + "`n" + 'from .forms import DeveloperForm, GameDetailForm, GameForm, GenreForm, TagForm')
        $origModelImport = 'from .models import Game'
        if (-not $views.Contains($origModelImport)) { throw "Не найден импорт Game в views.py" }
        $views = $views.Replace($origModelImport, 'from .models import Developer, Game, GameDetail, Genre, Tag')
        $views = $views.TrimEnd() + "`n`n`n" + @'
# Практическая работа №3: отдельные страницы с формой и списком для пяти моделей.
def _database_page(request, form_class, items, template, title, route_name):
    form = form_class(request.POST if request.method == "POST" else None)
    if request.method == "POST" and form.is_valid():
        form.save()
        messages.success(request, "Запись успешно добавлена.")
        return redirect("store:" + route_name)
    return render(request, template, {"form": form, "items": items, "page_title": title})


def database_index(request):
    return render(request, "store/db_index.html")


def database_genres(request):
    return _database_page(request, GenreForm, Genre.objects.all(),
                          "store/db_genres.html", "Жанры", "database_genres")


def database_games(request):
    return _database_page(request, GameForm,
                          Game.objects.select_related("genre", "developer").prefetch_related("tags"),
                          "store/db_games.html", "Игры", "database_games")


def database_developers(request):
    return _database_page(request, DeveloperForm, Developer.objects.all(),
                          "store/db_developers.html", "Разработчики", "database_developers")


def database_details(request):
    return _database_page(request, GameDetailForm, GameDetail.objects.select_related("game"),
                          "store/db_details.html", "Информация об играх", "database_details")


def database_tags(request):
    return _database_page(request, TagForm, Tag.objects.all(),
                          "store/db_tags.html", "Метки", "database_tags")
'@
        Write-Utf8 $viewsPath $views
    }

    $urlsPath = "store/urls.py"
    $urls = Get-Content -LiteralPath $urlsPath -Raw -Encoding UTF8
    if ($urls -notmatch 'database_index') {
        $marker = '    path("about/", views.about, name="about"),'
        if (-not $urls.Contains($marker)) { throw "Не найден маршрут about/ в store/urls.py" }
        $extra = @'
    path("database/", views.database_index, name="database_index"),
    path("database/genres/", views.database_genres, name="database_genres"),
    path("database/games/", views.database_games, name="database_games"),
    path("database/developers/", views.database_developers, name="database_developers"),
    path("database/details/", views.database_details, name="database_details"),
    path("database/tags/", views.database_tags, name="database_tags"),
'@
        $urls = $urls.Replace($marker, $marker + "`n" + $extra.TrimEnd())
        Write-Utf8 $urlsPath $urls
    }

    $basePath = "store/templates/store/base.html"
    $base = Get-Content -LiteralPath $basePath -Raw -Encoding UTF8
    if ($base -notmatch 'database_index') {
        $anchor = '            <a class="admin-nav-link"'
        if (-not $base.Contains($anchor)) { throw "Не найдена ссылка на админ-панель в base.html" }
        $base = $base.Replace($anchor, '            <a class="database-nav-link" href="{% url ''store:database_index'' %}">База данных</a>' + "`n" + $anchor)
        Write-Utf8 $basePath $base
    }

    $stylePath = "store/static/store/style.css"
    $style = Get-Content -LiteralPath $stylePath -Raw -Encoding UTF8
    if ($style -notmatch '\.database-section') {
        $style = $style.TrimEnd() + "`n`n" + @'
/* Практическая работа №3: страницы базы данных */
.database-section { padding: 38px 0 75px; }
.database-links { display: flex; flex-wrap: wrap; gap: 12px; }
.database-links a { background: var(--panel2); padding: 17px 22px; border: 1px solid var(--line); border-radius: 12px; text-decoration: none; font-weight: 700; }
.database-links a:hover { background: var(--accent); }
.database-back { margin-bottom: 22px; }
.database-back a { color: var(--accent2); text-decoration: none; }
.database-panel { padding: 26px; margin: 0 0 24px; background: var(--panel); border: 1px solid var(--line); border-radius: 15px; }
.database-panel h2 { font-size: 23px; margin-bottom: 20px; }
.database-field { margin-bottom: 15px; }
.database-field label { display: block; margin-bottom: 7px; font-weight: 700; }
.database-field input:not([type=checkbox]), .database-field textarea, .database-field select { width: min(100%, 650px); padding: 10px 12px; border: 1px solid #464e65; border-radius: 7px; background: var(--panel2); color: var(--text); font: inherit; }
.database-field input[type=checkbox] { height: 17px; width: 17px; }
.database-field select[multiple] { min-height: 100px; }
.database-field small { display: block; margin-top: 4px; color: var(--muted); }
.database-error { color: #ff8585; margin-top: 5px; }
.database-success { padding: 12px; background: #153729; color: #aeefc7; border-radius: 8px; margin-bottom: 18px; }
.database-submit { padding: 12px 24px; background: var(--accent); border: 0; border-radius: 8px; color: #fff; font-weight: 700; cursor: pointer; }
.database-table-wrap { overflow-x: auto; }
.database-table { width: 100%; border-collapse: collapse; }
.database-table th, .database-table td { padding: 11px; text-align: left; border-bottom: 1px solid var(--line); vertical-align: top; }
.database-table th { color: var(--accent2); }
.navigation a.database-nav-link { color: var(--accent2); }
@media(max-width:800px) { .database-panel { padding: 16px; } .database-table { min-width: 600px; } }
'@
        Write-Utf8 $stylePath $style
    }

    Write-Host "[3/6] Команда наполнения БД, тесты и документация" -ForegroundColor Cyan
    Write-Utf8 "store/management/commands/seed_practical3.py" @'
from django.core.management import call_command
from django.core.management.base import BaseCommand
from store.models import Developer, Game, GameDetail, Tag


class Command(BaseCommand):
    help = "Создать тестовые записи для практической №3 без повторов."

    def handle(self, *args, **options):
        call_command("seed_gamestore", stdout=self.stdout)
        for name, country in [("Orbit Studio", "Россия"), ("Forge Games", "Польша"), ("North Pixel", "Канада")]:
            Developer.objects.get_or_create(name=name, defaults={"country": country})
        for name in ["Одиночная игра", "Контроллер", "Открытый мир"]:
            Tag.objects.get_or_create(name=name)

        assignments = [
            ("Neon Drift", "North Pixel", 2024, "ПК", "12+", ["Контроллер"]),
            ("Kingdom Forge", "Forge Games", 2025, "ПК", "16+", ["Открытый мир", "Одиночная игра"]),
            ("Deep Orbit", "Orbit Studio", 2025, "ПК", "12+", ["Одиночная игра", "Открытый мир"]),
        ]
        for title, developer_name, year, platform, rating, tag_names in assignments:
            game = Game.objects.get(title=title)
            if game.developer_id is None:
                game.developer = Developer.objects.get(name=developer_name)
                game.save(update_fields=["developer"])
            GameDetail.objects.get_or_create(game=game, defaults={
                "release_year": year, "platform": platform, "age_rating": rating,
            })
            game.tags.add(*Tag.objects.filter(name__in=tag_names))
        self.stdout.write(self.style.SUCCESS(
            f"Практическая №3: разработчиков {Developer.objects.count()}, "
            f"меток {Tag.objects.count()}, карточек {GameDetail.objects.count()}"
        ))
'@
    Write-Utf8 "store/test_practical3.py" @'
from django.core.management import call_command
from django.test import Client, TestCase
from django.urls import reverse
from .forms import GameDetailForm, GameForm
from .models import Developer, Game, GameDetail, Genre, Tag


class PracticalThreeTests(TestCase):
    def setUp(self):
        self.genre = Genre.objects.create(name="Гонки")
        self.developer = Developer.objects.create(name="Учебная студия", country="Россия")
        self.game = Game.objects.create(
            title="Гоночный тест", genre=self.genre, developer=self.developer,
            price=999, description="Тестовая игра", image="store/img/neon-drift.png",
        )

    def test_five_table_pages_work(self):
        names = ["database_genres", "database_games", "database_developers",
                 "database_details", "database_tags"]
        for name in names:
            with self.subTest(name=name):
                response = self.client.get(reverse("store:" + name))
                self.assertEqual(response.status_code, 200)
                self.assertContains(response, 'name="csrfmiddlewaretoken"')
        self.assertEqual(self.client.get(reverse("store:database_index")).status_code, 200)

    def test_create_genre_and_show_in_list(self):
        url = reverse("store:database_genres")
        self.assertEqual(self.client.post(url, {"name": "Стратегии", "description": "Пошаговые игры"}).status_code, 302)
        self.assertContains(self.client.get(url), "Стратегии")

    def test_invalid_genre_displays_error_and_does_not_save(self):
        response = self.client.post(reverse("store:database_genres"), {"name": ""})
        self.assertEqual(response.status_code, 200)
        self.assertContains(response, 'role="alert"')
        self.assertEqual(Genre.objects.count(), 1)

    def test_create_developer_and_tag(self):
        self.assertEqual(self.client.post(reverse("store:database_developers"), {
            "name": "Новая студия", "country": "Россия", "website": "https://example.com"
        }).status_code, 302)
        self.assertEqual(self.client.post(reverse("store:database_tags"), {"name": "Кооператив"}).status_code, 302)
        self.assertTrue(Developer.objects.filter(name="Новая студия").exists())
        self.assertTrue(Tag.objects.filter(name="Кооператив").exists())

    def test_invalid_developer_site(self):
        r = self.client.post(reverse("store:database_developers"), {
            "name": "Студия 2", "country": "Россия", "website": "not-a-url"
        })
        self.assertEqual(r.status_code, 200)
        self.assertFalse(Developer.objects.filter(name="Студия 2").exists())
        self.assertContains(r, 'role="alert"')

    def test_game_price_validation(self):
        form = GameForm(data={"title": "Бесплатная игра", "genre": self.genre.pk,
            "developer": self.developer.pk, "price": 0, "description": "Описание",
            "image": "store/img/neon-drift.png"})
        self.assertFalse(form.is_valid())
        self.assertIn("price", form.errors)

    def test_create_game_with_many_to_many_tags(self):
        tag = Tag.objects.create(name="Контроллер")
        response = self.client.post(reverse("store:database_games"), {
            "title": "Новая игра", "genre": self.genre.pk, "developer": self.developer.pk,
            "price": "500", "description": "Игровое описание",
            "image": "store/img/neon-drift.png", "tags": [tag.pk], "available": "on",
        })
        self.assertEqual(response.status_code, 302)
        new_game = Game.objects.get(title="Новая игра")
        self.assertIn(tag, new_game.tags.all())
        self.assertContains(self.client.get(reverse("store:database_games")), "Новая игра")

    def test_create_game_detail_one_to_one(self):
        url = reverse("store:database_details")
        payload = {"game": self.game.pk, "release_year": "2024", "platform": "ПК", "age_rating": "12+"}
        self.assertEqual(self.client.post(url, payload).status_code, 302)
        self.assertEqual(self.game.details.release_year, 2024)
        invalid = self.client.post(url, payload)
        self.assertEqual(invalid.status_code, 200)
        self.assertContains(invalid, 'role="alert"')
        self.assertEqual(GameDetail.objects.count(), 1)

    def test_future_year_rejected(self):
        form = GameDetailForm(data={"game": self.game.pk, "release_year": 9999,
                                     "platform": "ПК", "age_rating": "12+"})
        self.assertFalse(form.is_valid())
        self.assertIn("release_year", form.errors)

    def test_csrf_is_enforced(self):
        strict = Client(enforce_csrf_checks=True)
        response = strict.post(reverse("store:database_tags"), {"name": "Без токена"})
        self.assertEqual(response.status_code, 403)
        self.assertFalse(Tag.objects.filter(name="Без токена").exists())

    def test_seed_is_repeatable(self):
        call_command("seed_practical3", verbosity=0)
        call_command("seed_practical3", verbosity=0)
        self.assertEqual(Genre.objects.count(), 6)
        self.assertEqual(Game.objects.count(), 7)
        self.assertEqual(Developer.objects.count(), 4)  # одна из setUp + три тестовых
        self.assertEqual(Tag.objects.count(), 3)
        self.assertEqual(GameDetail.objects.count(), 3)
'@
    Write-Utf8 "REPORT_PRACTICAL3.md" @'
# Практическая работа №3 «Подключение к базе данных»

**Дисциплина:** МДК 03.02 «Разработка кода информационных ресурсов»  
**Группа:** ВТ-1-24  
**Проект:** GameStore

## Цель
Подключить веб-приложение к базе данных, реализовать пять предметных моделей с тремя видами связей, добавить веб-формы и вывод записей с валидацией.

## Ход работы
1. Использована уже существующая база SQLite и две модели: `Genre` и `Game`.
2. Добавлены модели `Developer`, `Tag`, `GameDetail`. Всего в приложении пять основных моделей; Django также создаёт связующую таблицу для `ManyToManyField`.
3. Связь «один к одному»: `GameDetail.game` (`OneToOneField`). Связь «один ко многим»: `Game.genre` и `Game.developer` (`ForeignKey`). Связь «многие ко многим»: `Game.tags` (`ManyToManyField`).
4. В `store/forms.py` добавлены пять `ModelForm` для создания записей. Цена проверяется на положительность, год выхода — на допустимый диапазон, обязательные поля и адрес сайта проверяются Django.
5. Для каждой модели создана отдельная страница со списком записей и POST-формой. Формы защищены `{% csrf_token %}`, ошибки отображаются на странице под полями.
6. Добавлены команда `python manage.py seed_practical3` для тестовых данных и автоматические тесты, проверяющие добавление, фильтрацию значений, связи, валидацию и CSRF.
7. Каталог и административная панель из предыдущих практических сохранены, в шапку добавлена ссылка «База данных».

## Проверка на компьютере
```powershell
.\.venv\Scripts\python.exe manage.py makemigrations
.\.venv\Scripts\python.exe manage.py migrate
.\.venv\Scripts\python.exe manage.py seed_practical3
.\.venv\Scripts\python.exe manage.py test
.\.venv\Scripts\python.exe manage.py runserver
```

После запуска проверьте `http://127.0.0.1:8000/database/` и страницы всех пяти таблиц. Для итогового отчёта снимите реальные скриншоты форм, списков и ошибок валидации.

## Вывод
В ходе выполнения данной практической работы веб-приложение GameStore расширено моделями базы данных с отношениями один к одному, один ко многим и многие ко многим; реализованы формы добавления и страницы просмотра записей, обработка ошибок и защита CSRF.

## Репозиторий
https://github.com/lilqbite-svg/GameStore_Practical1
'@

    $readmePath = "README.md"
    $readme = Get-Content -LiteralPath $readmePath -Raw -Encoding UTF8
    if ($readme -notmatch 'Практическая работа №3') {
        $readme += @'

## Практическая работа №3 «Подключение к базе данных»

Добавлены пять предметных моделей и три типа связей: один к одному, один ко многим и многие ко многим.
Созданы страницы просмотра и добавления записей через `forms.py`, вывод ошибок и защита CSRF.

```powershell
py manage.py migrate
py manage.py seed_practical3
py manage.py runserver
```

Страницы таблиц: http://127.0.0.1:8000/database/ . Подробности: [отчёт №3](REPORT_PRACTICAL3.md).
'@
        Write-Utf8 $readmePath $readme
    }

    if ($PSCommandPath -and (Test-Path -LiteralPath $PSCommandPath)) {
        $copyTo = Join-Path $ProjectDir "Update_GameStore_Practical3.ps1"
        if (([System.IO.Path]::GetFullPath($PSCommandPath)) -ne ([System.IO.Path]::GetFullPath($copyTo))) {
            Copy-Item -LiteralPath $PSCommandPath -Destination $copyTo -Force
        }
    }

    Write-Host "[4/6] Установка Django и применение миграций" -ForegroundColor Cyan
    $python = Join-Path $ProjectDir ".venv\Scripts\python.exe"
    if (-not (Test-Path $python)) {
        if (-not (Get-Command py -ErrorAction SilentlyContinue)) { throw "Не найден py.exe (Python)" }
        Run-Checked "py" @("-m", "venv", ".venv")
    }
    Run-Checked $python @("-m", "pip", "install", "-r", "requirements.txt")
    Run-Checked $python @("manage.py", "check")
    Run-Checked $python @("manage.py", "makemigrations", "store", "--noinput")
    Run-Checked $python @("manage.py", "migrate", "--noinput")
    Run-Checked $python @("manage.py", "seed_practical3")

    Write-Host "[5/6] Проверка миграций, тесты Django и git diff" -ForegroundColor Cyan
    Run-Checked $python @("manage.py", "makemigrations", "--check", "--dry-run")
    Run-Checked $python @("manage.py", "test")
    Run-Checked "git" @("diff", "--check")

    Write-Host "[6/6] Публикация в том же GitHub-репозитории" -ForegroundColor Cyan
    if ($NoPush) {
        Write-Host "Режим -NoPush: проверено локально, но в GitHub ничего не отправлено." -ForegroundColor Yellow
    } else {
        Run-Checked "git" @("add", "README.md", "REPORT_PRACTICAL3.md", "Update_GameStore_Practical3.ps1", "store/models.py", "store/admin.py", "store/forms.py", "store/views.py", "store/urls.py", "store/management/commands/seed_practical3.py", "store/test_practical3.py", "store/templates/store", "store/static/store/style.css", "store/migrations")
        $changes = @(git diff --cached --name-only)
        if ($changes.Count -gt 0) {
            Run-Checked "git" @("commit", "-m", "Практическая работа №3: подключение к базе данных и формы")
            Run-Checked "git" @("push", "origin", "main")
        }
        Write-Host "Готово. Репозиторий: https://github.com/lilqbite-svg/GameStore_Practical1" -ForegroundColor Green
    }
    Write-Host "Таблицы и формы: http://127.0.0.1:8000/database/" -ForegroundColor Cyan
    Write-Host "Для запуска: cd $ProjectDir ; .\.venv\Scripts\python.exe manage.py runserver" -ForegroundColor Cyan
} finally {
    Pop-Location
}
