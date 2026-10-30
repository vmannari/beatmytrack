"""Directly authored translations for the missing-terms instruction."""
from pathlib import Path
import json

ROOT = Path(__file__).resolve().parents[3]
SOURCE = "Please accept the Terms of Service to continue."
VALUES = {
    "en": SOURCE,
    "fr": "Veuillez accepter les conditions d’utilisation pour continuer.",
    "es": "Acepta los términos de servicio para continuar.",
    "de": "Bitte akzeptiere die Nutzungsbedingungen, um fortzufahren.",
    "pt_BR": "Aceite os Termos de Serviço para continuar.",
    "ja": "続行するには利用規約に同意してください。",
    "ko": "계속하려면 서비스 약관에 동의해 주세요.",
    "nl": "Accepteer de servicevoorwaarden om door te gaan.",
    "it": "Accetta i Termini di servizio per continuare.",
    "fi": "Hyväksy käyttöehdot jatkaaksesi.",
    "sv": "Godkänn användarvillkoren för att fortsätta.",
    "nb": "Godta bruksvilkårene for å fortsette.",
    "messages": "",
}
for locale, value in VALUES.items():
    path = ROOT / "game/localization" / ("messages.pot" if locale == "messages" else locale + ".po")
    text = path.read_bytes().decode("utf-8")
    key = "msgid " + json.dumps(SOURCE, ensure_ascii=False) + "\n"
    start = text.index(key) + len(key)
    end = text.index("\n", start)
    assert text[start:end].startswith("msgstr ")
    text = text[:start] + "msgstr " + json.dumps(value, ensure_ascii=False) + text[end:]
    path.write_bytes(text.encode("utf-8"))
print("UTF-8 warning copy written for twelve locales.")
