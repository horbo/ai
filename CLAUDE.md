# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Czym jest to repozytorium

Skrypt `ai` (bash) generujacy komende shellowa na podstawie promptu w jezyku
naturalnym. Do tego `install.sh` (instalator dla `curl | bash`) i `tests/`.
Brak systemu budowania i zaleznosci poza `claude`, `jq` i `git`.

Repo jest publikowane jako `horbo/ai`, branch glowny `main`.

## Uruchamianie i weryfikacja zmian

```bash
tests/run.sh                            # PIERWSZY wybor - nie wysyla zapytan do modelu
./ai lista plikow wiekszych niz 100MB   # realne zapytanie, kosztuje
bash -n ai && shellcheck ai
```

`tests/run.sh` podmienia `claude` na stub w PATH (`tests/stub/claude`, sterowany
`STUB_CASE`), sprawdza kontrakt stdout/stderr i kody wyjscia, a instalator uruchamia
end-to-end w `mktemp -d` na tymczasowym repo zbudowanym z drzewa roboczego.
Zmieniajac parsowanie wyjscia albo instalacje, dopisz przypadek do tego pliku,
zamiast testowac przez realne wywolania.

## Architektura

Skrypt swiadomie **tylko wypisuje komende na stdout i nigdy jej nie wykonuje**.
Uruchomieniem zajmuje sie owijka powloki generowana przez `ai init zsh|bash`,
ktora w zsh wklada wynik do bufora edycji przez `print -z`. Ten podzial jest
kluczowy - nie dodawaj do skryptu wykonywania (`eval`, `bash -c`) wygenerowanej
komendy.

Niezmiennik, ktorego pilnuja testy: **na stdout nie trafia nic poza komenda**.
Pomoc, wersja, wyjasnienia, ostrzezenia, pytania i bledy ida na stderr. Wyjatkiem
jest `ai init`, ktorego wyjscie jest konsumowane przez `eval`.

Kody wyjscia: `0` komenda, `1` blad uzycia lub brak zaleznosci, `2` model prosi
o doprecyzowanie (pytanie na stderr), `3` awaria CLI `claude`.

Przeplyw: parsowanie flag (konczy sie na pierwszym argumencie niebedacym flaga,
`--` wymusza koniec) → input z argumentow, stdin lub `read` → `build_context()`
→ wywolanie `claude` z `--json-schema` i `--output-format json` → `jq` na
`.is_error`, `.structured_output.question`, `.structured_output.command` → stdout.

Format odpowiedzi kontroluja **dwa** miejsca: `SCHEMA` (structured output wymuszany
przez CLI) i `SYSTEM_PROMPT` (kiedy uzyc `command`, a kiedy `question`, jezyk
odpowiedzi). Zmieniajac jedno, sprawdz drugie. `strip_fences` to juz tylko pas
bezpieczenstwa na wypadek, gdyby model wsadzil markdown do pola `command`.

Wywolanie `claude` jest zahardenowane: `--tools ""`, `--permission-mode dontAsk`,
`--permission-prompts none`, `--setting-sources ""`, `--strict-mcp-config`,
`--no-session-persistence`. To odcina narzedzia, `CLAUDE.md` z cwd, hooki i MCP,
i jest zauwazalnie szybsze. Nie uzywaj `--bare` - wymaga `ANTHROPIC_API_KEY`
i nie czyta OAuth.

Wywolanie `claude` nie moze stac bezposrednio pod `set -e` (`response=$(...) || status=$?`),
bo CLI zwraca niezerowy kod przy bledzie API, a chcemy wtedy wypisac tresc z `.result`.

Logika instalacji zyje **w `ai`** (`link_binary`, `ensure_rc_block`, podkomenda
`--link`); `install.sh` po sklonowaniu repo tylko wola `ai --link`. Nie duplikuj
tam sed-ow ani znacznikow. Dzieki temu `ai --update` naprawia zepsuty symlink
i brakujacy wpis w rc.

## Konwencje

- **Wszystko w repozytorium po angielsku**: kod, nazwy, komunikaty dla uzytkownika,
  tekst `--help`, system prompt, README, testy, komunikaty commitow.
- **Komentarze do absolutnego minimum, najlepiej zero.** Zamiast komentarza -
  czytelna nazwa funkcji lub zmiennej. Jedna linia wyjasnienia tylko tam, gdzie kod
  robi cos nieoczywistego wbrew pozorom.
- `set -euo pipefail` na gorze kazdego skryptu; trzymaj sie tego przy dodawaniu kodu.
- Komunikaty na stderr z prefiksem `ai:` (helpery `log` i `die`).
