from django.shortcuts import render
from .models import Game


def home(request):
    return render(request, "store/home.html")


def catalog(request):
    games = Game.objects.filter(available=True).select_related("genre")
    return render(request, "store/catalog.html", {"games": games})


def about(request):
    return render(request, "store/about.html")
