"""Preview the website on loopback without a database or real account actions.

Run .tools/backend-venv/Scripts/python.exe scripts/preview_public_website.py
and open http://127.0.0.1:8086. Stop with Ctrl+C.
"""
import argparse

import uvicorn
from fastapi import FastAPI

from bmt_backend import privacy_pages, public_pages
from bmt_backend.community import public_rules
from bmt_backend.config import Settings


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--port", type=int, default=8086)
    arguments = parser.parse_args()
    app = FastAPI(docs_url=None, redoc_url=None, openapi_url=None)
    app.state.settings = Settings(environment="test")
    app.include_router(public_pages.router)
    app.include_router(privacy_pages.router)
    app.get("/community-rules")(public_rules)
    print(f"Website preview: http://127.0.0.1:{arguments.port}", flush=True)
    print("Preview only: Google verification and account deletion are disabled.", flush=True)
    uvicorn.run(app, host="127.0.0.1", port=arguments.port, access_log=False)


if __name__ == "__main__":
    main()
