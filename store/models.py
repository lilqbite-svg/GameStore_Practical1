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
    developer = models.ForeignKey("Developer", on_delete=models.PROTECT, null=True, blank=True, related_name="games", verbose_name="Разработчик")
    tags = models.ManyToManyField("Tag", blank=True, related_name="games", verbose_name="Метки")

    class Meta:
        verbose_name = "игра"
        verbose_name_plural = "игры"
        ordering = ["title"]

    def __str__(self):
        return self.title


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
