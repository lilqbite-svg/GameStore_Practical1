from django.urls import path
from . import views

app_name = "store"

urlpatterns = [
    path("", views.home, name="home"),
    path("catalog/", views.catalog, name="catalog"),
    path("about/", views.about, name="about"),
    path("database/", views.database_index, name="database_index"),
    path("database/genres/", views.database_genres, name="database_genres"),
    path("database/games/", views.database_games, name="database_games"),
    path("database/developers/", views.database_developers, name="database_developers"),
    path("database/details/", views.database_details, name="database_details"),
    path("database/tags/", views.database_tags, name="database_tags"),
]
