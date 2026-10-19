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
