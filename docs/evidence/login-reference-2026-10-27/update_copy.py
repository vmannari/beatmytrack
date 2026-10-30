"""Append this task's directly authored login copy without rewriting other rows."""
from pathlib import Path
import json

ROOT = Path(__file__).resolve().parents[3]
KEYS = [
    "Ready to race?",
    "Sign in to save results online, join events and race friends.",
    "Continue with Google",
    "Play as guest",
    "Local progress stays on this device. Events require sign-in.",
]
COPY = {
    "en": KEYS,
    "fr": ["Prêt à courir ?", "Connectez-vous pour enregistrer vos résultats en ligne, participer aux événements et affronter vos amis.", "Continuer avec Google", "Jouer en invité", "La progression locale reste sur cet appareil. Les événements nécessitent une connexion."],
    "es": ["¿Listo para correr?", "Inicia sesión para guardar resultados en línea, participar en eventos y competir con amigos.", "Continuar con Google", "Jugar como invitado", "El progreso local se guarda en este dispositivo. Los eventos requieren iniciar sesión."],
    "de": ["Bereit fürs Rennen?", "Melde dich an, um Ergebnisse online zu speichern, an Events teilzunehmen und gegen Freunde zu fahren.", "Mit Google fortfahren", "Als Gast spielen", "Lokaler Fortschritt bleibt auf diesem Gerät. Events erfordern eine Anmeldung."],
    "pt_BR": ["Pronto para correr?", "Entre para salvar resultados online, participar de eventos e correr com amigos.", "Continuar com o Google", "Jogar como convidado", "O progresso local fica neste dispositivo. Os eventos exigem login."],
    "ja": ["レースの準備はできた？", "ログインして結果をオンラインに保存し、イベントに参加して友達と競おう。", "Google で続ける", "ゲストとしてプレイ", "ローカルの進行状況はこの端末に保存されます。イベントにはログインが必要です。"],
    "ko": ["레이스할 준비됐나요?", "로그인해서 기록을 온라인에 저장하고, 이벤트에 참가하고, 친구들과 겨뤄 보세요.", "Google로 계속하기", "게스트로 플레이", "로컬 진행 상황은 이 기기에 저장됩니다. 이벤트에 참가하려면 로그인해야 합니다."],
    "nl": ["Klaar om te racen?", "Log in om resultaten online op te slaan, aan evenementen mee te doen en tegen vrienden te racen.", "Doorgaan met Google", "Spelen als gast", "Lokale voortgang blijft op dit apparaat. Voor evenementen moet je inloggen."],
    "it": ["Pronto a correre?", "Accedi per salvare i risultati online, partecipare agli eventi e gareggiare con gli amici.", "Continua con Google", "Gioca come ospite", "I progressi locali restano su questo dispositivo. Gli eventi richiedono l'accesso."],
    "fi": ["Valmiina kisaan?", "Kirjaudu sisään tallentaaksesi tulokset verkkoon, osallistuaksesi tapahtumiin ja kisataksesi kavereiden kanssa.", "Jatka Google-tilillä", "Pelaa vieraana", "Paikallinen edistyminen säilyy tällä laitteella. Tapahtumat vaativat kirjautumisen."],
    "sv": ["Redo att tävla?", "Logga in för att spara resultat online, delta i evenemang och tävla mot vänner.", "Fortsätt med Google", "Spela som gäst", "Lokala framsteg sparas på den här enheten. Evenemang kräver inloggning."],
    "nb": ["Klar for et løp?", "Logg inn for å lagre resultater på nett, delta i arrangementer og kjøre mot venner.", "Fortsett med Google", "Spill som gjest", "Lokal fremgang lagres på denne enheten. Arrangementer krever innlogging."],
}

TERMS_KEYS = ["Terms of Service (draft)", "I agree to the {terms}", "I agree to the draft Terms of Service", "Save a copy", "Could not save the terms. Please try again."]
TERMS_COPY = {
    "en": TERMS_KEYS,
    "fr": ["Conditions d'utilisation (brouillon)", "J'accepte les {terms}", "J'accepte le brouillon des conditions d'utilisation", "Enregistrer une copie", "Impossible d'enregistrer les conditions. Réessayez."],
    "es": ["Términos de servicio (borrador)", "Acepto los {terms}", "Acepto el borrador de los términos de servicio", "Guardar una copia", "No se pudieron guardar los términos. Inténtalo de nuevo."],
    "de": ["Nutzungsbedingungen (Entwurf)", "Ich akzeptiere die {terms}", "Ich akzeptiere den Entwurf der Nutzungsbedingungen", "Kopie speichern", "Die Bedingungen konnten nicht gespeichert werden. Bitte versuche es erneut."],
    "pt_BR": ["Termos de Serviço (rascunho)", "Concordo com os {terms}", "Concordo com o rascunho dos Termos de Serviço", "Salvar uma cópia", "Não foi possível salvar os termos. Tente novamente."],
    "ja": ["利用規約（草案）", "{terms}に同意します", "利用規約の草案に同意します", "コピーを保存", "規約を保存できませんでした。もう一度お試しください。"],
    "ko": ["서비스 약관(초안)", "{terms}에 동의합니다", "서비스 약관 초안에 동의합니다", "사본 저장", "약관을 저장할 수 없습니다. 다시 시도해 주세요."],
    "nl": ["Servicevoorwaarden (concept)", "Ik ga akkoord met de {terms}", "Ik ga akkoord met het concept van de servicevoorwaarden", "Een kopie opslaan", "De voorwaarden konden niet worden opgeslagen. Probeer het opnieuw."],
    "it": ["Termini di servizio (bozza)", "Accetto i {terms}", "Accetto la bozza dei Termini di servizio", "Salva una copia", "Impossibile salvare i termini. Riprova."],
    "fi": ["Käyttöehdot (luonnos)", "Hyväksyn {terms}", "Hyväksyn käyttöehtojen luonnoksen", "Tallenna kopio", "Ehtoja ei voitu tallentaa. Yritä uudelleen."],
    "sv": ["Användarvillkor (utkast)", "Jag godkänner {terms}", "Jag godkänner utkastet till användarvillkoren", "Spara en kopia", "Det gick inte att spara villkoren. Försök igen."],
    "nb": ["Bruksvilkår (utkast)", "Jeg godtar {terms}", "Jeg godtar utkastet til bruksvilkårene", "Lagre en kopi", "Kunne ikke lagre vilkårene. Prøv igjen."],
}
for locale in COPY:
    COPY[locale] = COPY[locale] + TERMS_COPY[locale]
KEYS = KEYS + TERMS_KEYS

for locale, values in {**COPY, "messages": [""] * len(KEYS)}.items():
    path = ROOT / "game/localization" / ("messages.pot" if locale == "messages" else locale + ".po")
    original = path.read_bytes()
    text = original.decode("utf-8")
    additions = []
    for key, value in zip(KEYS, values, strict=True):
        quoted_key = json.dumps(key, ensure_ascii=False)
        if "msgid " + quoted_key + "\n" in text.replace("\r\n", "\n"):
            continue
        source = "google_sign_in_button.gd" if "Google" in key else "account_panel.gd"
        additions.append(f"#: game/ui/{source}\nmsgid {quoted_key}\nmsgstr {json.dumps(value, ensure_ascii=False)}\n")
    if additions:
        path.write_bytes(original + ("\n" + "\n".join(additions)).encode("utf-8"))
    print(locale, len(additions))
