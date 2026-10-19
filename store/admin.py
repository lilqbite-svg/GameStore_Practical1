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
