$ErrorActionPreference = "Stop"

$repo = "https://github.com/lilqbite-svg/GameStore_Practical1.git"

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    throw "Git не найден. Установите Git for Windows и повторите запуск."
}

if (-not (Test-Path ".git")) {
    git init
}

git add .
$hasHead = git rev-parse --verify HEAD 2>$null
if ($LASTEXITCODE -ne 0) {
    git commit -m "Практическая работа №1 - GameStore"
} else {
    $changes = git status --porcelain
    if ($changes) {
        git commit -m "Обновление практической работы №1"
    }
}

git branch -M main
$origin = git remote 2>$null | Select-String -SimpleMatch "origin"
if ($origin) {
    git remote set-url origin $repo
} else {
    git remote add origin $repo
}

git push -u origin main
