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
