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
