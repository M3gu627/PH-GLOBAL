import os
import json
import requests
from datetime import datetime, date
from playwright.sync_api import sync_playwright
import google.auth
import google.auth.transport.requests
from google.oauth2 import service_account

DFA_SITES = [
    {"id": "5", "name": "DFA NCR Central (Robinsons Galleria Ortigas, Quezon City)"},
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
    """Use Playwright to go through DFA appointment flow and collect available dates."""
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

                # Intercept the availability API response
                api_response = []
                def handle_response(response):
                    if "timeslot/available" in response.url:
                        try:
                            data = response.json()
                            api_response.extend(data)
                            print(f"  Intercepted {len(data)} slots for {site_name}")
                        except Exception as e:
                            print(f"  Could not parse timeslot response: {e}")

                page.on("response", handle_response)

                # Step 1: Go to appointment page and agree to terms
                print(f"\nProcessing {site_name}...")
                page.goto(f"{BASE_URL}/appointment", wait_until="domcontentloaded", timeout=30000)
                page.wait_for_timeout(1000)

                # Check the agree checkbox and click Individual
                page.check("#agree")
                page.click("button[value='Individual']")
                page.wait_for_url("**/individual/site", timeout=15000)
                print(f"  Reached site selection page")

                # Step 2: Select region, country, and site
                page.select_option("select[name='SiteRegionID']", "1")
                page.wait_for_timeout(1000)

                page.select_option("select[name='SiteCountryID']", "1")
                page.wait_for_timeout(1000)

                page.select_option("select[name='SiteID']", site_id)
                page.wait_for_timeout(1000)

                # Check all notification checkboxes
                for cb in ["cl-notif-checkbox", "pubpow-notif-checkbox",
                           "ofw-notif-checkbox", "renewal-notif-checkbox", "co-notif-checkbox"]:
                    try:
                        page.check(f"#{cb}")
                    except Exception:
                        pass

                # Click Next
                page.click("input[value='Next'], button:has-text('Next')")
                page.wait_for_url("**/individual/schedule", timeout=15000)
                print(f"  Reached schedule page")

                # Wait for availability API call to complete
                page.wait_for_timeout(5000)

                # Parse available dates from intercepted response
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
        f"{SUPABASE_URL}/rest/v1/slots?agency_id=eq.dfa&select=slot_date",
        headers=SUPABASE_HEADERS
    )
    return {row["slot_date"] for row in res.json()}


def insert_slot(date_str):
    requests.post(
        f"{SUPABASE_URL}/rest/v1/slots",
        headers=SUPABASE_HEADERS,
        json={"agency_id": "dfa", "slot_date": date_str}
    )
    print(f"  Inserted: {date_str}")


def delete_slot(date_str):
    requests.delete(
        f"{SUPABASE_URL}/rest/v1/slots?agency_id=eq.dfa&slot_date=eq.{date_str}",
        headers=SUPABASE_HEADERS
    )
    print(f"  Deleted: {date_str}")


def get_subscribed_tokens():
    res = requests.get(
        f"{SUPABASE_URL}/rest/v1/subscriptions?agency_id=eq.dfa&select=fcm_token",
        headers=SUPABASE_HEADERS
    )
    return [row["fcm_token"] for row in res.json()]


def send_push_notification(tokens, new_dates, access_token):
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
                    "body": f"New slots open: {', '.join(new_dates)}"
                },
                "data": {"agency_id": "dfa"}
            }
        }
        res = requests.post(url, headers=headers, json=payload)
        print(f"  FCM {token[:20]}...: {res.status_code}")


def run():
    print(f"Scraper started at {datetime.now()}")

    all_results = fetch_all_dates()

    scraped_dates = set()
    for dates in all_results.values():
        scraped_dates.update(dates)

    print(f"Total available dates found: {len(scraped_dates)}")

    current_dates = get_current_slots()
    new_dates = scraped_dates - current_dates
    removed_dates = current_dates - scraped_dates

    for d in new_dates:
        insert_slot(d)
    for d in removed_dates:
        delete_slot(d)

    if new_dates:
        access_token = get_fcm_access_token()
        tokens = get_subscribed_tokens()
        send_push_notification(tokens, list(new_dates), access_token)
    else:
        print("No new slots found.")

    print("Scraper finished.")


if __name__ == "__main__":
    run()