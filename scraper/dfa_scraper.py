import os
import json
import requests
from datetime import datetime, date
from playwright.sync_api import sync_playwright
import google.auth
import google.auth.transport.requests
from google.oauth2 import service_account

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

BASE_URL = "https://passport.gov.ph"
SUPABASE_URL = os.environ["SUPABASE_URL"]
SUPABASE_KEY = os.environ["SUPABASE_KEY"]
FCM_SERVICE_ACCOUNT = json.loads(os.environ["FCM_SERVICE_ACCOUNT"])
PROJECT_ID = "ph-global"

SUPABASE_HEADERS = {
    "apikey": SUPABASE_KEY,
    "Authorization": f"Bearer {SUPABASE_KEY}",
    "Content-Type": "application/json"
}


def get_fcm_access_token():
    credentials = service_account.Credentials.from_service_account_info(
        FCM_SERVICE_ACCOUNT,
        scopes=["https://www.googleapis.com/auth/firebase.messaging"]
    )
    request = google.auth.transport.requests.Request()
    credentials.refresh(request)
    return credentials.token


def fetch_all_dates():
    results = {}

    with sync_playwright() as p:
        browser = p.chromium.launch(args=["--no-sandbox"])
        context = browser.new_context(
            user_agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
        )

        for site in DFA_SITES:
            site_id = site["id"]
            site_name = site["name"]
            available_dates = []

            try:
                page = context.new_page()
                api_response = []

                def handle_response(response, sid=site_id, sname=site_name):
                    if "timeslot/available" in response.url:
                        try:
                            data = response.json()
                            api_response.extend(data)
                            print(f"  Intercepted {len(data)} slots for {sname}")
                        except Exception as e:
                            print(f"  Could not parse timeslot response: {e}")

                page.on("response", handle_response)

                print(f"\nProcessing {site_name}...")
                page.goto(f"{BASE_URL}/appointment", wait_until="domcontentloaded", timeout=30000)
                page.wait_for_timeout(1000)

                page.check("#agree")
                page.click("button[value='Individual']")
                page.wait_for_url("**/individual/site", timeout=15000)
                print(f"  Reached site selection page")

                page.select_option("select[name='SiteRegionID']", "1")
                page.wait_for_timeout(1000)

                page.select_option("select[name='SiteCountryID']", "1")
                page.wait_for_timeout(1000)

                page.select_option("select[name='SiteID']", site_id)
                page.wait_for_timeout(1000)

                for cb in ["cl-notif-checkbox", "pubpow-notif-checkbox",
                           "ofw-notif-checkbox", "renewal-notif-checkbox", "co-notif-checkbox"]:
                    try:
                        page.check(f"#{cb}")
                    except Exception:
                        pass

                page.click("input[value='Next'], button:has-text('Next')")
                page.wait_for_url("**/individual/schedule", timeout=15000)
                print(f"  Reached schedule page")

                page.wait_for_timeout(5000)

                available_dates = [
                    datetime.utcfromtimestamp(s["AppointmentDate"] / 1000).strftime("%Y-%m-%d")
                    for s in api_response if s.get("IsAvailable")
                ]
                print(f"  Available dates: {available_dates}")

            except Exception as e:
                print(f"  Error for {site_name}: {e}")
            finally:
                page.close()

            results[site_id] = available_dates

        browser.close()

    return results


def get_current_slots():
    res = requests.get(
        f"{SUPABASE_URL}/rest/v1/slots?agency_id=eq.dfa&select=slot_date,site_id",
        headers=SUPABASE_HEADERS
    )
    return {(row["site_id"], row["slot_date"]) for row in res.json()}


def insert_slot(date_str, site_id):
    requests.post(
        f"{SUPABASE_URL}/rest/v1/slots",
        headers=SUPABASE_HEADERS,
        json={"agency_id": "dfa", "slot_date": date_str, "site_id": site_id}
    )
    print(f"  Inserted: {date_str} (site {site_id})")


def delete_slot(date_str, site_id):
    requests.delete(
        f"{SUPABASE_URL}/rest/v1/slots?agency_id=eq.dfa&slot_date=eq.{date_str}&site_id=eq.{site_id}",
        headers=SUPABASE_HEADERS
    )
    print(f"  Deleted: {date_str} (site {site_id})")


def get_subscribed_tokens(site_id):
    res = requests.get(
        f"{SUPABASE_URL}/rest/v1/subscriptions?agency_id=eq.dfa&site_id=eq.{site_id}&select=fcm_token",
        headers=SUPABASE_HEADERS
    )
    return [row["fcm_token"] for row in res.json()]


def send_push_notification(tokens, new_dates, access_token, site_name):
    if not tokens:
        print("No subscribers, skipping notification.")
        return

    url = f"https://fcm.googleapis.com/v1/projects/{PROJECT_ID}/messages:send"
    headers = {
        "Authorization": f"Bearer {access_token}",
        "Content-Type": "application/json"
    }
    for token in tokens:
        payload = {
            "message": {
                "token": token,
                "notification": {
                    "title": "DFA Slot Available!",
                    "body": f"{site_name}: {', '.join(new_dates)}"
                },
                "data": {"agency_id": "dfa"}
            }
        }
        res = requests.post(url, headers=headers, json=payload)
        print(f"  FCM {token[:20]}...: {res.status_code}")


def run():
    print(f"Scraper started at {datetime.now()}")

    all_results = fetch_all_dates()

    current_slots = get_current_slots()
    scraped_slots = set()

    for site_id, dates in all_results.items():
        for d in dates:
            scraped_slots.add((site_id, d))

    new_slots = scraped_slots - current_slots
    removed_slots = current_slots - scraped_slots

    for site_id, d in new_slots:
        insert_slot(d, site_id)
    for site_id, d in removed_slots:
        delete_slot(d, site_id)

    notified_sites = set()
    for site_id, d in new_slots:
        if site_id not in notified_sites:
            tokens = get_subscribed_tokens(site_id)
            if tokens:
                access_token = get_fcm_access_token()
                new_dates_for_site = [d for s, d in new_slots if s == site_id]
                site_name = next((s["name"] for s in DFA_SITES if s["id"] == site_id), site_id)
                send_push_notification(tokens, new_dates_for_site, access_token, site_name)
            notified_sites.add(site_id)

    if not new_slots:
        print("No new slots found.")

    print("Scraper finished.")


if __name__ == "__main__":
    run()