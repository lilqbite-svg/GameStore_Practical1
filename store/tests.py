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
