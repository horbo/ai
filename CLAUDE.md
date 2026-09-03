# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Czym jest to repozytorium

Jednoplikowy projekt: skrypt `ai` (bash) generujacy komende shellowa na podstawie
promptu w jezyku naturalnym. Brak systemu budowania, zaleznosci i testow.

## Uruchamianie i weryfikacja zmian

```bash
./ai lista plikow wiekszych niz 100MB   # prompt z argumentow
./ai                                    # tryb interaktywny (read -p)
bash -n ai                              # sprawdzenie skladni
shellcheck ai                           # lint (jesli dostepny)
```

Skrypt wymaga w PATH CLI `claude` (wywoluje `claude --model haiku --system-prompt ... -p ...`).
Kazde uruchomienie to realne zapytanie do modelu — przy testowaniu zmian w parsowaniu
wyjscia taniej jest podmienic `claude` na stub w PATH niz odpalac skrypt w petli.

## Architektura

Skrypt swiadomie **tylko wypisuje komende na stdout i nigdy jej nie wykonuje**.
Uruchomieniem zajmuje sie owijka po stronie uzytkownika w `.zshrc` (funkcja `ai`),
ktora wklada wynik do bufora edycji zsh przez `print -z`, dzieki czemu uzytkownik
widzi komende przed nacisnieciem Enter. Ten podzial jest kluczowy — nie dodawaj
do skryptu wykonywania (`eval`, `bash -c`) wygenerowanej komendy.

Przeplyw: input (argumenty lub `read`) → walidacja pustego promptu → wywolanie
`claude` z system promptem wymuszajacym "jedna komenda, zero komentarza" →
sanityzacja wyjscia (usuniecie ogrodzen markdown i pustych linii przez `sed`) →
`printf` na stdout. Bledy ida na stderr z kodem 1.

System prompt jest zdefiniowany inline w zmiennej `system_prompt` i jest jedynym
miejscem kontrolujacym format odpowiedzi modelu. Sanityzacja `sed` to zabezpieczenie
na wypadek zignorowania instrukcji — zmieniajac jedno, sprawdz drugie.

## Konwencje

- Komunikaty i komentarze po polsku, ale **bez polskich znakow diakrytycznych**
  (ASCII), zgodnie z reszta pliku.
- `set -euo pipefail` na gorze; trzymaj sie tego przy dodawaniu kodu.
