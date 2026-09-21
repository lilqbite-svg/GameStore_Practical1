from django.test import TestCase
from django.urls import reverse


class PageTests(TestCase):
    def test_home_page(self):
        self.assertEqual(self.client.get(reverse("store:home")).status_code, 200)

    def test_catalog_page(self):
        self.assertEqual(self.client.get(reverse("store:catalog")).status_code, 200)

    def test_about_page(self):
        self.assertEqual(self.client.get(reverse("store:about")).status_code, 200)
