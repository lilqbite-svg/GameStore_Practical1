from django.contrib import messages
from django.shortcuts import redirect, render
from .forms import DeveloperForm, GameDetailForm, GameForm, GenreForm, TagForm
from .models import Developer, Game, GameDetail, Genre, Tag


def home(request):
    return render(request, "store/home.html")


def catalog(request):
    games = Game.objects.filter(available=True).select_related("genre")
    return render(request, "store/catalog.html", {"games": games})


def about(request):
    return render(request, "store/about.html")


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
