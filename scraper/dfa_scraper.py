import os
import json
import requests
from datetime import datetime
from playwright.sync_api import sync_playwright
import google.auth
import google.auth.transport.requests
from google.oauth2 import service_account

DFA_LOCATIONS = [
    {"slug": "dfa-ncr-central", "label": "DFA NCR Central"},
    {"slug": "dfa-ncr-north",   "label": "DFA NCR North"},
    {"slug": "dfa-ncr-south",   "label": "DFA NCR South"},
    {"slug": "dfa-ncr-west",    "label": "DFA NCR West"},
]

BASE_URL = "https://dfacalendar.netpinoy.com/philippines"
SUPABASE_URL = os.environ["SUPABASE_URL"]
SUPABASE_KEY = os.environ["SUPABASE_KEY"]
FCM_SERVICE_ACCOUNT = json.loads(os.environ["FCM_SERVICE_ACCOUNT"])
PROJECT_ID = "ph-global"

HEADERS = {
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


def fetch_all_dates_playwright():
    dates = {loc["slug"]: [] for loc in DFA_LOCATIONS}

    with sync_playwright() as p:
        browser = p.chromium.launch()
        page = browser.new_page()

        for loc in DFA_LOCATIONS:
            slug = loc["slug"]
            url = f"{BASE_URL}/{slug}"
            print(f"Fetching {url}...")

            try:
                page.goto(url, wait_until="domcontentloaded", timeout=60000)
                page.wait_for_timeout(5000)

                content = page.inner_text("body")
                print(f"  Snippet: {content[:300]}")

                for line in content.split("\n"):
                    line = line.strip()
                    if "Earliest Date:" in line:
                        date_str = line.replace("Earliest Date:", "").strip()
                        try:
                            date = datetime.strptime(date_str, "%b %d, %Y").date()
                            dates[slug].append(str(date))
                            print(f"  Found date: {date}")
                        except ValueError:
                            pass

            except Exception as e:
                print(f"  Error fetching {slug}: {e}")
                continue

        browser.close()

    return dates


def get_current_slots():
    res = requests.get(
        f"{SUPABASE_URL}/rest/v1/slots?agency_id=eq.dfa&select=slot_date",
        headers=HEADERS
    )
    return {row["slot_date"] for row in res.json()}


def insert_slot(date):
    requests.post(
        f"{SUPABASE_URL}/rest/v1/slots",
        headers=HEADERS,
        json={"agency_id": "dfa", "slot_date": date}
    )
    print(f"Inserted slot: {date}")


def delete_slot(date):
    requests.delete(
        f"{SUPABASE_URL}/rest/v1/slots?agency_id=eq.dfa&slot_date=eq.{date}",
        headers=HEADERS
    )
    print(f"Deleted slot: {date}")


def get_subscribed_tokens():
    res = requests.get(
        f"{SUPABASE_URL}/rest/v1/subscriptions?agency_id=eq.dfa&select=fcm_token",
        headers=HEADERS
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
        print(f"FCM response for {token[:20]}...: {res.status_code}")


def run():
    print(f"Scraper started at {datetime.now()}")

    all_dates = fetch_all_dates_playwright()

    scraped_dates = set()
    for loc in DFA_LOCATIONS:
        dates = all_dates[loc["slug"]]
        print(f"{loc['label']}: {dates}")
        scraped_dates.update(dates)

    current_dates = get_current_slots()
    new_dates = scraped_dates - current_dates
    removed_dates = current_dates - scraped_dates

    for date in new_dates:
        insert_slot(date)
    for date in removed_dates:
        delete_slot(date)

    if new_dates:
        access_token = get_fcm_access_token()
        tokens = get_subscribed_tokens()
        send_push_notification(tokens, list(new_dates), access_token)
    else:
        print("No new slots found.")

    print("Scraper finished.")


if __name__ == "__main__":
    run()