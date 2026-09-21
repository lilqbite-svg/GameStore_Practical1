# GameStore — практическая работа №1

**Тема:** интернет-магазин цифровых копий компьютерных игр.

Учебный Django-проект для практической работы №1 «Создание первого проекта».

## Быстрый запуск в Windows PowerShell

```powershell
git clone https://github.com/lilqbite-svg/GameStore_Practical1.git
cd GameStore_Practical1
py -m venv .venv
.\.venv\Scripts\Activate.ps1
py -m pip install -r requirements.txt
py manage.py migrate
py manage.py runserver
```

После запуска откройте:

- `http://127.0.0.1:8000/` — главная;
- `http://127.0.0.1:8000/catalog/` — каталог;
- `http://127.0.0.1:8000/about/` — «О нас».

## Репозиторий

https://github.com/lilqbite-svg/GameStore_Practical1
