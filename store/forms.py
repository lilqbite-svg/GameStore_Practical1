from datetime import date
from django import forms
from .models import Developer, Game, GameDetail, Genre, Tag


class GenreForm(forms.ModelForm):
    class Meta:
        model = Genre
        fields = ["name", "description", "is_active"]


class DeveloperForm(forms.ModelForm):
    class Meta:
        model = Developer
        fields = ["name", "country", "website"]


class TagForm(forms.ModelForm):
    class Meta:
        model = Tag
        fields = ["name"]


class GameForm(forms.ModelForm):
    class Meta:
        model = Game
        fields = ["title", "genre", "developer", "price", "description", "image", "tags", "available"]
        widgets = {"description": forms.Textarea(attrs={"rows": 3})}

    def clean_price(self):
        price = self.cleaned_data["price"]
        if price <= 0:
            raise forms.ValidationError("Цена должна быть больше нуля.")
        return price


class GameDetailForm(forms.ModelForm):
    class Meta:
        model = GameDetail
        fields = ["game", "release_year", "platform", "age_rating"]

    def clean_release_year(self):
        year = self.cleaned_data["release_year"]
        if year < 1980 or year > date.today().year:
            raise forms.ValidationError("Укажите год с 1980 по текущий год.")
        return year
