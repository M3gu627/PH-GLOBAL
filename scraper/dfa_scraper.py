import os
import json
import requests
from bs4 import BeautifulSoup
from datetime import datetime
import google.auth
import google.auth.transport.requests
from google.oauth2 import service_account

# Config
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


def fetch_available_dates(slug):
    url = f"{BASE_URL}/{slug}"
    res = requests.get(url, timeout=10)
    soup = BeautifulSoup(res.text, "html.parser")

    # Debug: print all strong tags
    strongs = soup.find_all("strong")
    print(f"[{slug}] Found {len(strongs)} strong tags:")
    for s in strongs[:10]:  # print first 10 only
        print(f"  -> {s.get_text(strip=True)}")

    dates = []
    for tag in strongs:
        text = tag.get_text(strip=True)
        if text.startswith("Earliest Date:"):
            date_str = text.replace("Earliest Date:", "").strip()
            try:
                date = datetime.strptime(date_str, "%b %d, %Y").date()
                dates.append(str(date))
            except ValueError:
                pass

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
        print(f"FCM response for {token[:20]}...: {res.status_code} {res.text}")


def run():
    print(f"Scraper started at {datetime.now()}")

    scraped_dates = set()
    for loc in DFA_LOCATIONS:
        dates = fetch_available_dates(loc["slug"])
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