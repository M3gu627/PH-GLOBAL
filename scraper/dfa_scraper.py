import os
import json
import asyncio
import requests
from datetime import datetime
from playwright.async_api import async_playwright
import google.auth
import google.auth.transport.requests
from google.oauth2 import service_account

# ---------------------------------------------------------------------------
# Site list
# ---------------------------------------------------------------------------

DFA_SITES = [
    {"id": "10",  "name": "Angeles (SM City Clark, Angeles City)"},
    {"id": "486", "name": "Antipolo (SM Center, Antipolo City, Rizal)"},
    {"id": "693", "name": "Antique (CityMall Antique)"},
    {"id": "11",  "name": "Bacolod (Robinsons Bacolod)"},
    {"id": "12",  "name": "Baguio (SM City Baguio)"},
    {"id": "703", "name": "Balanga (The Bunker Building, Capitol Compound)"},
    {"id": "14",  "name": "Butuan (Robinsons Butuan)"},
    {"id": "15",  "name": "Cagayan De Oro (BPO Tower SM Downtown Premier)"},
    {"id": "16",  "name": "Calasiao (Robinsons Calasiao, Pangasinan)"},
    {"id": "702", "name": "Candon (Candon City Arena)"},
    {"id": "17",  "name": "Cebu (Robinsons Galleria, Cebu City)"},
    {"id": "487", "name": "Clarin (Town Center, Clarin, Misamis OCC)"},
    {"id": "4",   "name": "DFA Manila (Aseana)"},
    {"id": "5",   "name": "DFA NCR Central (Robinsons Galleria Ortigas, Quezon City)"},
    {"id": "6",   "name": "DFA NCR East (SM Megamall, Mandaluyong City)"},
    {"id": "423", "name": "DFA NCR North (Robinsons Novaliches, Quezon City)"},
    {"id": "7",   "name": "DFA NCR Northeast (Ali Mall Cubao, Quezon City)"},
    {"id": "704", "name": "DFA NCR South (Festival Mall, Muntinlupa City)"},
    {"id": "9",   "name": "DFA NCR West (SM City, Manila)"},
    {"id": "488", "name": "Dasmarinas (SM City Dasmarinas)"},
    {"id": "19",  "name": "Davao (SM City Davao)"},
    {"id": "20",  "name": "Dumaguete (Robinsons Dumaguete)"},
    {"id": "21",  "name": "General Santos (Robinsons Gen. Santos City)"},
    {"id": "22",  "name": "Iloilo (Robinsons Iloilo)"},
    {"id": "690", "name": "Kidapawan (Kidapawan City)"},
    {"id": "23",  "name": "La Union (CSI Mall San Fernando)"},
    {"id": "24",  "name": "Legazpi (Pacific Mall Legazpi)"},
    {"id": "13",  "name": "Lipa (Robinsons Lipa)"},
    {"id": "25",  "name": "Lucena (Pacific Mall, Lucena)"},
    {"id": "489", "name": "Malolos (CTTCH., Xentro Mall, Malolos City)"},
    {"id": "705", "name": "Olongapo (SM City Olongapo Central)"},
    {"id": "694", "name": "Pagadian (C3 Mall, Pagadian City)"},
    {"id": "27",  "name": "Pampanga (Robinsons StarMills San Fernando)"},
    {"id": "553", "name": "Paniqui, Tarlac (WalterMart)"},
    {"id": "26",  "name": "Puerto Princesa (Robinsons Palawan)"},
    {"id": "425", "name": "Santiago, Isabela (Robinsons Place Santiago)"},
    {"id": "28",  "name": "Tacloban (Robinsons N. Abucay, Tac. City)"},
    {"id": "709", "name": "Tagbilaran (Alturas Mall, Tagbilaran City)"},
    {"id": "491", "name": "Tagum (Robinsons Place of Tagum)"},
    {"id": "29",  "name": "Tuguegarao (Reg. Govt Center, Tuguegarao City)"},
    {"id": "30",  "name": "Zamboanga (Go-Velayo Bldg. Vet. Ave. Zambo)"},
]

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------

BASE_URL = "https://passport.gov.ph"
SUPABASE_URL = os.environ["SUPABASE_URL"]
SUPABASE_KEY = os.environ["SUPABASE_KEY"]
FCM_SERVICE_ACCOUNT = json.loads(os.environ["FCM_SERVICE_ACCOUNT"])
PROJECT_ID = "ph-global"

MAX_RETRIES = 2
RETRY_BASE_DELAY = 3

SUPABASE_HEADERS = {
    "apikey": SUPABASE_KEY,
    "Authorization": f"Bearer {SUPABASE_KEY}",
    "Content-Type": "application/json",
}

BATCH_INDEX = int(os.environ.get("BATCH_INDEX", "0"))
BATCH_TOTAL = int(os.environ.get("BATCH_TOTAL", "1"))


def get_sites_for_this_batch(sites):
    return sites[BATCH_INDEX::BATCH_TOTAL]


# ---------------------------------------------------------------------------
# Supabase helpers
# ---------------------------------------------------------------------------

def get_current_slots():
    res = requests.get(
        f"{SUPABASE_URL}/rest/v1/slots?agency_id=eq.dfa&select=slot_date,site_id",
        headers=SUPABASE_HEADERS,
    )
    return {(row["site_id"], row["slot_date"]) for row in res.json()}


def insert_slot(date_str, site_id):
    requests.post(
        f"{SUPABASE_URL}/rest/v1/slots",
        headers=SUPABASE_HEADERS,
        json={"agency_id": "dfa", "slot_date": date_str, "site_id": site_id},
    )
    print(f"  Inserted: {date_str} (site {site_id})")


def delete_slot(date_str, site_id):
    requests.delete(
        f"{SUPABASE_URL}/rest/v1/slots?agency_id=eq.dfa&slot_date=eq.{date_str}&site_id=eq.{site_id}",
        headers=SUPABASE_HEADERS,
    )
    print(f"  Deleted: {date_str} (site {site_id})")


def get_subscribed_tokens(site_id):
    res = requests.get(
        f"{SUPABASE_URL}/rest/v1/subscriptions?agency_id=eq.dfa&site_id=eq.{site_id}&select=fcm_token",
        headers=SUPABASE_HEADERS,
    )
    return [row["fcm_token"] for row in res.json()]


# ---------------------------------------------------------------------------
# FCM helpers
# ---------------------------------------------------------------------------

def get_fcm_access_token():
    credentials = service_account.Credentials.from_service_account_info(
        FCM_SERVICE_ACCOUNT,
        scopes=["https://www.googleapis.com/auth/firebase.messaging"],
    )
    req = google.auth.transport.requests.Request()
    credentials.refresh(req)
    return credentials.token


def send_push_notification(tokens, new_dates, access_token, site_name):
    if not tokens:
        print("  No subscribers — skipping notification.")
        return
    url = f"https://fcm.googleapis.com/v1/projects/{PROJECT_ID}/messages:send"
    headers = {
        "Authorization": f"Bearer {access_token}",
        "Content-Type": "application/json",
    }
    for token in tokens:
        payload = {
            "message": {
                "token": token,
                "notification": {
                    "title": "DFA Slot Available!",
                    "body": f"{site_name}: {', '.join(new_dates)}",
                },
                "data": {"agency_id": "dfa"},
            }
        }
        res = requests.post(url, headers=headers, json=payload)
        print(f"  FCM {token[:20]}...: {res.status_code}")


# ---------------------------------------------------------------------------
# Core scrape logic
# ---------------------------------------------------------------------------

async def scrape_site_once(browser, site) -> list[str]:
    site_id = site["id"]
    api_response = []

    page = await browser.new_page(
        user_agent=(
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
            "AppleWebKit/537.36 (KHTML, like Gecko) "
            "Chrome/120.0.0.0 Safari/537.36"
        ),
        viewport={"width": 1280, "height": 800},
        locale="en-US",
    )

    slot_received = asyncio.Event()

    async def handle_response(response):
        if "timeslot/available" in response.url:
            try:
                data = await response.json()
                api_response.extend(data)
                print(f"    [{site_id}] Intercepted {len(data)} slot records")
                # DEBUG: print first 3 records to inspect full structure
                print(f"    [{site_id}] Sample records: {json.dumps(data[:3], indent=2)}")
                slot_received.set()
            except Exception as e:
                print(f"    [{site_id}] Could not parse timeslot response: {e}")

    page.on("response", handle_response)

    try:
        print(f"    [{site_id}] Loading appointment page...")
        await page.goto(
            f"{BASE_URL}/appointment",
            wait_until="domcontentloaded",
            timeout=60000,
        )

        await page.wait_for_selector("#agree", state="visible", timeout=20000)
        await page.check("#agree")

        print(f"    [{site_id}] Navigating to site selection...")
        await page.click("button[value='Individual']")

        await page.wait_for_selector(
            "select[name='SiteRegionID']", state="visible", timeout=45000
        )

        await page.select_option("select[name='SiteRegionID']", "1")
        await page.wait_for_timeout(3000)

        await page.select_option("select[name='SiteCountryID']", "1")
        await page.wait_for_timeout(3000)

        await page.select_option("select[name='SiteID']", site_id)
        await page.wait_for_timeout(1000)

        for cb in [
            "cl-notif-checkbox",
            "pubpow-notif-checkbox",
            "ofw-notif-checkbox",
            "renewal-notif-checkbox",
            "co-notif-checkbox",
        ]:
            try:
                await page.check(f"#{cb}", timeout=2000)
            except Exception:
                pass

        print(f"    [{site_id}] Submitting site selection...")
        next_btn = page.locator("input[value='Next'], button:has-text('Next')")
        await next_btn.wait_for(state="visible", timeout=10000)
        await next_btn.click()

        await page.wait_for_url("**/individual/schedule", timeout=45000)

        print(f"    [{site_id}] Waiting for timeslot API response...")
        try:
            await asyncio.wait_for(slot_received.wait(), timeout=5.0)
        except asyncio.TimeoutError:
            print(f"    [{site_id}] No timeslot API response received (likely no slots)")

        available_dates = [
            datetime.utcfromtimestamp(s["AppointmentDate"] / 1000).strftime("%Y-%m-%d")
            for s in api_response
            if s.get("IsAvailable")
        ]
        print(f"    [{site_id}] Available dates: {available_dates or 'none'}")
        return available_dates

    finally:
        await page.close()


# ---------------------------------------------------------------------------
# Retry wrapper
# ---------------------------------------------------------------------------

async def scrape_site_with_retry(browser, site) -> tuple[str, list[str] | None]:
    site_id = site["id"]
    site_name = site["name"]

    for attempt in range(1, MAX_RETRIES + 1):
        try:
            print(f"\n  [{site_id}] Attempt {attempt}/{MAX_RETRIES}: {site_name}")
            dates = await scrape_site_once(browser, site)
            return site_id, dates

        except Exception as e:
            print(f"  [{site_id}] Attempt {attempt} failed: {type(e).__name__}: {str(e)[:120]}")
            if attempt < MAX_RETRIES:
                delay = RETRY_BASE_DELAY * (2 ** (attempt - 1))
                print(f"  [{site_id}] Retrying in {delay}s...")
                await asyncio.sleep(delay)
            else:
                print(f"  [{site_id}] All {MAX_RETRIES} attempts failed. Skipping.")

    return site_id, None


# ---------------------------------------------------------------------------
# Sequential fetch
# ---------------------------------------------------------------------------

async def fetch_all_dates_async(sites_to_scrape) -> dict:
    results = {}
    site_log = []
    total = len(sites_to_scrape)
    batch_start = datetime.now()

    BROWSER_ARGS = [
        "--no-sandbox",
        "--disable-setuid-sandbox",
        "--disable-dev-shm-usage",
        "--disable-gpu",
        "--disable-extensions",
        "--disable-background-networking",
        "--no-first-run",
        "--no-default-browser-check",
    ]

    async with async_playwright() as p:
        for i, site in enumerate(sites_to_scrape, 1):
            site_start = datetime.now()
            elapsed_batch = (site_start - batch_start).seconds

            print(f"\n{'='*60}")
            print(f"  PROGRESS: {i}/{total} sites | Batch elapsed: {elapsed_batch}s")
            print(f"  Remaining: {total - i + 1} sites")
            print(f"{'='*60}")

            browser = await p.chromium.launch(headless=True, args=BROWSER_ARGS)
            try:
                site_id, dates = await scrape_site_with_retry(browser, site)
            finally:
                await browser.close()

            results[site_id] = dates if dates is not None else []

            site_elapsed = (datetime.now() - site_start).seconds
            if dates is None:
                status = "✗ FAILED"
                slot_count = 0
            elif len(dates) == 0:
                status = "○ NO SLOTS"
                slot_count = 0
            else:
                status = "✓ SUCCESS"
                slot_count = len(dates)

            site_log.append({
                "id": site_id,
                "name": site["name"],
                "status": status,
                "slots": slot_count,
                "elapsed": site_elapsed,
            })

            print(f"  [{site_id}] {status} | {slot_count} slots found | took {site_elapsed}s")
            await asyncio.sleep(2)

    total_elapsed = (datetime.now() - batch_start).seconds
    print(f"\n{'='*60}")
    print(f"  BATCH COMPLETE — {total_elapsed}s total")
    print(f"{'='*60}")
    print(f"  {'ID':<6} {'STATUS':<12} {'SLOTS':<8} {'TIME':<8} NAME")
    print(f"  {'-'*54}")
    for log in site_log:
        print(
            f"  {log['id']:<6} {log['status']:<12} {log['slots']:<8} "
            f"{str(log['elapsed'])+'s':<8} {log['name']}"
        )
    succeeded = sum(1 for l in site_log if l["status"] == "✓ SUCCESS")
    no_slots  = sum(1 for l in site_log if l["status"] == "○ NO SLOTS")
    failed    = sum(1 for l in site_log if l["status"] == "✗ FAILED")
    total_slots = sum(l["slots"] for l in site_log)
    print(f"  {'-'*54}")
    print(f"  ✓ Slots found: {succeeded} | ○ No slots: {no_slots} | ✗ Failed: {failed} | Total slots: {total_slots}")
    print(f"{'='*60}\n")

    return results


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def run():
    print(f"Scraper started at {datetime.now()} | batch {BATCH_INDEX + 1}/{BATCH_TOTAL}")

    batch_sites = get_sites_for_this_batch(DFA_SITES)
    print(f"  Batch covers {len(batch_sites)} sites: {[s['id'] for s in batch_sites]}")

    sites_to_scrape = batch_sites
    print(f"  Scraping all {len(sites_to_scrape)} sites in batch")

    all_results = asyncio.run(fetch_all_dates_async(sites_to_scrape))

    current_slots = get_current_slots()
    scraped_slots = {
        (site_id, d)
        for site_id, dates in all_results.items()
        for d in dates
    }

    batch_site_ids = {s["id"] for s in sites_to_scrape}
    current_slots_for_batch = {
        (sid, d) for sid, d in current_slots if sid in batch_site_ids
    }

    new_slots = scraped_slots - current_slots_for_batch
    removed_slots = current_slots_for_batch - scraped_slots

    print(f"\n  New slots: {len(new_slots)} | Removed slots: {len(removed_slots)}")

    for site_id, d in new_slots:
        insert_slot(d, site_id)
    for site_id, d in removed_slots:
        delete_slot(d, site_id)

    if new_slots:
        access_token = get_fcm_access_token()
        notified_sites: set[str] = set()
        for site_id, _ in new_slots:
            if site_id in notified_sites:
                continue
            tokens = get_subscribed_tokens(site_id)
            if tokens:
                new_dates_for_site = [d for sid, d in new_slots if sid == site_id]
                site_name = next(
                    (s["name"] for s in DFA_SITES if s["id"] == site_id), site_id
                )
                send_push_notification(tokens, new_dates_for_site, access_token, site_name)
            notified_sites.add(site_id)
    else:
        print("  No new slots — no notifications sent.")

    print(f"\nScraper finished at {datetime.now()}")


if __name__ == "__main__":
    run()