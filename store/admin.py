from django.contrib import admin
from .models import Developer, Game, GameDetail, Genre, Tag


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
