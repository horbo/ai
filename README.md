# ai

Generator komend shellowych. Opisujesz po ludzku, co chcesz zrobić — skrypt zwraca
jedną gotową komendę bash.

Kluczowa zasada: **`ai` nigdy nie uruchamia wygenerowanej komendy**. Wypisuje ją
wyłącznie na stdout. Uruchomieniem zajmuje się owijka w `.zshrc`, która wkłada
komendę do bufora edycji zsh — widzisz ją, możesz poprawić i dopiero wtedy
naciskasz Enter.

## Wymagania

- `bash`
- CLI [`claude`](https://claude.ai/code) dostępne w `PATH` (skrypt korzysta z modelu Haiku)
- `zsh` — jeśli chcesz korzystać z owijki wstawiającej komendę do terminala

## Instalacja

Sklonuj repozytorium i podlinkuj skrypt w `PATH`, np.:

```bash
ln -s ~/Projects/ai_command/ai ~/.local/bin/ai-gen
```

Następnie dodaj do `~/.zshrc` funkcję, która wstawi wynik do bufora edycji:

```zsh
ai() {
    local cmd
    cmd="$(ai-gen "$@")" || return
    print -z -- "$cmd"
}
```

Po `source ~/.zshrc` wpisanie `ai ...` podstawi wygenerowaną komendę w linii poleceń,
gotową do przejrzenia i zatwierdzenia.

## Użycie

```bash
ai znajdź pliki większe niż 100 MB w katalogu domowym
ai wypisz procesy zajmujące najwięcej pamięci
ai                      # tryb interaktywny — zapyta o prompt
```

Bez owijki skrypt zachowuje się jak zwykły filtr i można go użyć w potoku:

```bash
ai-gen skasuj pliki .tmp starsze niż 7 dni | tee /dev/tty | bash   # na własną odpowiedzialność
```

## Jak to działa

1. Prompt pobierany jest z argumentów albo interaktywnie przez `read`.
2. Pusty prompt kończy działanie kodem 1 i komunikatem na stderr.
3. Wywoływany jest `claude --model haiku` z system promptem wymuszającym odpowiedź
   w postaci jednej komendy — bez komentarzy, wyjaśnień i pytań doprecyzowujących.
   Jeśli w prompcie czegoś brakuje, model ma przyjąć rozsądne założenie.
4. Wyjście jest sanityzowane: usuwane są ewentualne ogrodzenia markdown
   (linie zaczynające się od potrójnego backticka) oraz puste linie z początku i końca.
5. Pusta odpowiedź modelu również kończy się kodem 1.

## Uwagi

Model bywa omylny, a komendy shellowe bywają nieodwracalne. Sens tego narzędzia
polega na tym, że zawsze widzisz komendę przed uruchomieniem — przeczytaj ją,
zwłaszcza gdy zawiera `rm`, `dd`, `mkfs` czy przekierowania nadpisujące pliki.
