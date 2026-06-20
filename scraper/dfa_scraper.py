import os
import json
import requests
from datetime import datetime, date
from bs4 import BeautifulSoup
import google.auth
import google.auth.transport.requests
from google.oauth2 import service_account

# Testing with one site first
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

BROWSER_HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
    "Accept-Language": "en-US,en;q=0.5",
}


def get_csrf_token(html):
    soup = BeautifulSoup(html, "html.parser")
    token = soup.find("input", {"name": "__RequestVerificationToken"})
    return token["value"] if token else None


def create_session():
    session = requests.Session()
    session.headers.update(BROWSER_HEADERS)

    # Step 1: GET homepage
    res = session.get(f"{BASE_URL}/appointment", timeout=15)
    print(f"Step 1 (homepage): {res.status_code} -> {res.url}")

    # Step 2: POST terms agreement
    token = get_csrf_token(res.text)
    if not token:
        print("ERROR: No CSRF token on homepage")
        return None

    res = session.post(
        f"{BASE_URL}/appointment/terms",
        data={
            "__RequestVerificationToken": token,
            "agree": "on",
            "groupType": "Individual",
        },
        headers={"Referer": f"{BASE_URL}/appointment"},
        timeout=15
    )
    print(f"Step 2 (terms): {res.status_code} -> {res.url}")

    return session


def fetch_available_dates(session, site_id, site_name):
    try:
        # Re-fetch schedule page fresh for each site
        res = session.get(
            f"{BASE_URL}/appointment/individual/schedule",
            timeout=15
        )
        print(f"  Schedule page: {res.status_code} -> {res.url}")

        token = get_csrf_token(res.text)
        if not token:
            print(f"  No CSRF token for {site_name}")
            return []

        # POST site selection
        res = session.post(
            f"{BASE_URL}/appointment/individual/schedule",
            data={
                "__RequestVerificationToken": token,
                "CurrentStep": "site",
                "PreviousStep": "",
                "SiteID": site_id,
                "co-notif-checkbox": "on",
            },
            headers={"Referer": f"{BASE_URL}/appointment/individual/schedule"},
            timeout=15,
            allow_redirects=True
        )
        print(f"  After site POST: {res.status_code} -> {res.url}")
        print(f"  Page snippet: {res.text[200:500]}")

        # POST to availability API
        today = date.today().strftime("%Y-%m-%d")
        res = session.post(
            f"{BASE_URL}/appointment/timeslot/available",
            data={
                "fromDate": today,
                "toDate": "2026-12-31",
                "siteId": site_id,
                "requestedSlots": 1,
            },
            headers={"Referer": f"{BASE_URL}/appointment/individual/schedule"},
            timeout=15
        )
        print(f"  Availability: {res.status_code} -> {res.text[:300]}")

        if not res.text.strip() or res.text.strip() in ["null", "[]"]:
            return []

        slots = res.json()
        return [
            datetime.utcfromtimestamp(s["AppointmentDate"] / 1000).strftime("%Y-%m-%d")
            for s in slots if s.get("IsAvailable")
        ]

    except Exception as e:
        print(f"  Error for {site_name}: {e}")
        return []


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


def get_fcm_access_token():
    credentials = service_account.Credentials.from_service_account_info(
        FCM_SERVICE_ACCOUNT,
        scopes=["https://www.googleapis.com/auth/firebase.messaging"]
    )
    request = google.auth.transport.requests.Request()
    credentials.refresh(request)
    return credentials.token


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

    session = create_session()
    if not session:
        print("ERROR: Could not create session, aborting.")
        return

    scraped_dates = set()
    for site in DFA_SITES:
        dates = fetch_available_dates(session, site["id"], site["name"])
        if dates:
            print(f"  {site['name']}: {dates}")
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