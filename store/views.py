from django.shortcuts import render


GAMES = [
    {
        "title": "Neon Drift",
        "genre": "Гонки",
        "price": "1 499 ₽",
        "description": "Динамичные ночные заезды по улицам неонового мегаполиса.",
        "image": "store/img/neon-drift.png",
    },
    {
        "title": "Kingdom Forge",
        "genre": "RPG",
        "price": "1 999 ₽",
        "description": "Приключенческая ролевая игра в большом фэнтезийном мире.",
        "image": "store/img/kingdom-forge.png",
    },
    {
        "title": "Deep Orbit",
        "genre": "Приключения",
        "price": "2 499 ₽",
        "description": "Исследование далёкого космоса, планет и неизвестных станций.",
        "image": "store/img/deep-orbit.png",
    },
    {
        "title": "Iron Protocol",
        "genre": "Экшен",
        "price": "1 799 ₽",
        "description": "Тактический экшен о специальном отряде в городе будущего.",
        "image": "store/img/iron-protocol.png",
    },
    {
        "title": "Green Valley",
        "genre": "Симулятор",
        "price": "899 ₽",
        "description": "Спокойный симулятор развития собственной фермы и поселения.",
        "image": "store/img/green-valley.png",
    },
    {
        "title": "Zero Signal",
        "genre": "Хоррор",
        "price": "1 299 ₽",
        "description": "Мрачное приключение на заброшенном исследовательском комплексе.",
        "image": "store/img/zero-signal.png",
    },
]


def home(request):
    return render(request, "store/home.html")


def catalog(request):
    return render(request, "store/catalog.html", {"games": GAMES})


def about(request):
    return render(request, "store/about.html")
