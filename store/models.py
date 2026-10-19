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
