"""Small Google REST adapters; credentials use existing Application Default Credentials.

Errors intentionally exclude request URLs, purchase tokens and provider response bodies.
"""

import argparse
from datetime import date
from urllib.parse import quote

import google.auth
import requests
from fastapi import HTTPException
from google.auth.exceptions import GoogleAuthError
from google.auth.transport.requests import AuthorizedSession

from .provider_proofs import ProviderUnavailable, bounded_response


def transport(scope):
    credentials, _ = google.auth.default(scopes=[scope])
    return AuthorizedSession(credentials)


class PlayProvider:
    def __init__(self, settings):
        self.settings = settings

    def verify(self, token):
        url = (
            "https://androidpublisher.googleapis.com/androidpublisher/v3/applications/"
            + quote(self.settings.studio_play_package, safe="")
            + "/purchases/productsv2/tokens/"
            + quote(token, safe="")
        )
        try:
            with transport("https://www.googleapis.com/auth/androidpublisher") as client:
                response = client.get(url, timeout=10, allow_redirects=False, stream=True)
                return bounded_response(response)
        except HTTPException:
            raise
        except (GoogleAuthError, requests.RequestException, ValueError, ProviderUnavailable):
            raise HTTPException(503, "PLAY_VERIFICATION_UNAVAILABLE") from None

    def complete(self, product, token, proof):
        consumable = product.startswith("creator_slot") or product == "ad_free_month"
        if not consumable and proof.get("acknowledgementState") == "ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED":
            return
        if (
            consumable
            and proof["productLineItem"][0]["productOfferDetails"].get("consumptionState")
            == "CONSUMPTION_STATE_CONSUMED"
        ):
            return
        method = "consume" if consumable else "acknowledge"
        url = (
            "https://androidpublisher.googleapis.com/androidpublisher/v3/applications/"
            + quote(self.settings.studio_play_package, safe="")
            + "/purchases/products/"
            + quote(product, safe="")
            + "/tokens/"
            + quote(token, safe="")
            + ":"
            + method
        )
        try:
            with transport("https://www.googleapis.com/auth/androidpublisher") as client:
                response = client.post(
                    url, json={} if method == "acknowledge" else None, timeout=10, allow_redirects=False
                )
                if response.status_code not in (200, 204):
                    raise HTTPException(503, "PLAY_COMPLETION_RETRY_REQUIRED")
        except HTTPException:
            raise
        except (GoogleAuthError, requests.RequestException, ValueError):
            raise HTTPException(503, "PLAY_COMPLETION_RETRY_REQUIRED") from None


def admob(settings, first, last, currency):
    def day(value):
        return {"year": value.year, "month": value.month, "day": value.day}

    with transport("https://www.googleapis.com/auth/admob.report") as client:
        response = client.post(
            "https://admob.googleapis.com/v1/" + settings.studio_admob_account + "/networkReport:generate",
            json={
                "reportSpec": {
                    "dateRange": {"startDate": day(first), "endDate": day(last)},
                    "dimensions": ["DATE", "APP"],
                    "metrics": ["ESTIMATED_EARNINGS", "IMPRESSIONS"],
                    "localizationSettings": {"currencyCode": currency},
                    "timeZone": "America/Los_Angeles",
                    "maxReportRows": 1000,
                }
            },
            timeout=30,
            allow_redirects=False,
            stream=True,
        )
        return bounded_response(response, limit=2 * 1024 * 1024)


def main():
    parser = argparse.ArgumentParser(
        description="Import a complete Google AdMob network report; no fulfilment or price inference"
    )
    parser.add_argument("--since", type=date.fromisoformat, required=True)
    parser.add_argument("--through", type=date.fromisoformat, required=True)
    parser.add_argument("--currency", default="EUR")
    args = parser.parse_args()
    if not 0 <= (args.through - args.since).days <= 30:
        parser.error("Use a range of1–31 provider days")
    from .config import Settings
    from .db import make_engine, make_session_factory
    from .studio_finance import import_admob
    from .track_models import now

    settings = Settings.from_env()
    if not settings.studio_admob_account:
        parser.error("Configure studio_admob_account first")
    items = admob(settings, args.since, args.through, args.currency)
    engine = make_engine(settings.database_url, settings)
    try:
        with make_session_factory(engine)() as db:
            count = import_admob(db, settings.studio_admob_account, items, now())
        print("Imported " + str(count) + " monetary ledger entries")
    finally:
        engine.dispose()


if __name__ == "__main__":
    main()
