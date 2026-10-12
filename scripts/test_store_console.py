"""Opt-in real browser acceptance against the owned loopback purchase lab."""
import argparse
from pathlib import Path
from urllib.parse import urlsplit
from uuid import uuid4

import httpx
from playwright.sync_api import sync_playwright


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--url", default="http://127.0.0.1:18182")
    parser.add_argument("--data-dir", type=Path, default=Path("build/purchase-lab"))
    parser.add_argument("--output", type=Path, default=Path("docs/evidence/store-admin-2026-10-07"))
    args = parser.parse_args()
    parsed = urlsplit(args.url)
    if (parsed.hostname not in ("127.0.0.1", "localhost") or parsed.scheme != "http"
            or parsed.username or parsed.query or parsed.fragment or parsed.path not in ("", "/")):
        raise ValueError("Browser smoke is restricted to the owned loopback lab")
    key = (args.data_dir / "admin-owner.key").read_text().strip()
    dev = (args.data_dir / "development.key").read_text().strip()
    args.output.mkdir(parents=True, exist_ok=True)
    checks = 0
    with httpx.Client(base_url=args.url, timeout=15) as http:
        original = http.get("/v1/admin/products", headers={"Authorization":"Bearer "+key})
        original.raise_for_status()
        item = next(p for p in original.json()["items"] if p["id"] == "creator_slot_1")
        enabled = item["enabled"]
        def set_item(value):
            current = next(p for p in http.get("/v1/admin/products", headers={"Authorization":"Bearer "+key})
                .json()["items"] if p["id"] == "creator_slot_1")
            if current["enabled"] == value:
                return
            response = http.post("/v1/admin/products/creator_slot_1", headers={"Authorization":"Bearer "+key},
                json={"command_id":str(uuid4()),"enabled":value,"expected_revision":current["revision"],
                      "acknowledged":True,"reason":"Browser acceptance restore/test setup"})
            response.raise_for_status()
        set_item(True)
        try:
            login = http.post("/v1/auth/development", headers={"X-Dev-Auth-Key":dev},
                json={"subject":"store-console-"+uuid4().hex,"display_name":"Store console test "+uuid4().hex[:8]})
            login.raise_for_status()
            player = login.json()["player"]["id"]
            buyer = {"Authorization":"Bearer "+login.json()["access_token"]}
            pending = http.post("/v1/development/purchases", headers=buyer,
                json={"request_id":str(uuid4()),"product_id":"creator_slot_1","outcome":"pending"})
            pending.raise_for_status()
            with sync_playwright() as playwright:
                edge = Path(r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe")
                browser = playwright.chromium.launch(headless=True, executable_path=str(edge) if edge.exists() else None)
                page = browser.new_page(viewport={"width":1440,"height":1000})
                errors = []
                page.on("pageerror", lambda error: errors.append(str(error)))
                page.goto(args.url+"/admin#economy?player_id="+player)
                page.fill("#key", key)
                page.locator("#login button").click()
                page.wait_for_selector("[data-product='creator_slot_1']")
                assert page.locator("#purchase-filters input").input_value() == player
                assert "Simulation" in page.locator("#main").inner_text()
                checks += 2
                page.locator("[data-product='creator_slot_1']").click()
                page.fill("#product-reason", "Browser acceptance disable product")
                page.locator("#product-command input[type=checkbox]").check()
                page.locator("#product-submit").click()
                page.wait_for_selector("[data-product='creator_slot_1'][data-enabled='false']")
                denied = http.post("/v1/development/purchases",headers=buyer,
                    json={"request_id":str(uuid4()),"product_id":"creator_slot_1","outcome":"approved"})
                assert denied.status_code == 409 and denied.json()["detail"] == "PRODUCT_DISABLED"
                checks += 1
                approved = http.post("/v1/development/purchases/"+pending.json()["purchase"]["id"]+"/resolve",
                    headers=buyer,json={"outcome":"approved"})
                approved.raise_for_status()
                assert approved.json()["entitlements"]["publishing_slots"] == 2
                checks += 1
                page.locator("#refresh").click()
                page.wait_for_selector("[data-product='creator_slot_1'][data-enabled='false']")
                page.screenshot(path=str(args.output/"admin-purchases.png"),full_page=True)
                page.locator("[data-product='creator_slot_1']").click()
                page.fill("#product-reason","Browser acceptance enable product")
                page.locator("#product-command input[type=checkbox]").check()
                page.locator("#product-submit").click()
                page.wait_for_selector("[data-product='creator_slot_1'][data-enabled='true']")
                page.goto(args.url+"/admin#players/"+player)
                page.wait_for_selector("a[href='#economy?player_id="+player+"']")
                assert "simulated slots" in page.locator("#main").inner_text()
                checks += 1
                page.screenshot(path=str(args.output/"admin-player.png"),full_page=True)
                page.locator("#logout").click()
                page.wait_for_selector("#login")
                assert page.locator("#key").input_value() == ""
                assert not errors, errors
                checks += 2
                browser.close()
        finally:
            set_item(enabled)
    print(f"STORE_CONSOLE_BROWSER: {checks} checks, zero failures; availability restored")


if __name__ == "__main__":
    main()
