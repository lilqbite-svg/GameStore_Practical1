$ErrorActionPreference = "Stop"

if (-not (Test-Path ".venv")) {
    py -m venv .venv
}

. .\.venv\Scripts\Activate.ps1
py -m pip install -r requirements.txt
py manage.py migrate
Write-Host "Готово. Запуск: py manage.py runserver" -ForegroundColor Green
