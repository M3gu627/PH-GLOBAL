import os
import requests
from bs4 import BeautifulSoup
from datetime import datetime
import json

# Config — add more locations as needed
DFA_LOCATIONS = [
    {"slug": "dfa-ncr-central", "label": "DFA NCR Central"},
    {"slug": "dfa-ncr-north",   "label": "DFA NCR North"},
    {"slug": "dfa-ncr-south",   "label": "DFA NCR South"},
    {"slug": "dfa-ncr-west",    "label": "DFA NCR West"},
]

BASE_URL = "https://dfacalendar.netpinoy.com/philippines"
SUPABASE_URL = os.environ["SUPABASE_URL"]
SUPABASE_KEY = os.environ["SUPABASE_KEY"]
FCM_SERVER_KEY = os.environ["FCM_SERVER_KEY"]

HEADERS = {"apikey": SUPABASE_KEY, "Authorization": f"Bearer {SUPABASE_KEY}", "Content-Type": "application/json"}


def fetch_available_dates(slug):
    """Scrape available dates from dfacalendar.netpinoy.com for a given location."""
    url = f"{BASE_URL}/{slug}"
    res = requests.get(url, timeout=10)
    soup = BeautifulSoup(res.text, "html.parser")

    dates = []
    # The site lists available dates as highlighted calendar cells or text
    # Look for elements with class indicating availability
    for tag in soup.select(".available, .slot-date, td.success, td.open"):
        text = tag.get_text(strip=True)
        try:
            # Try parsing date text — adjust format if needed after first test run
            date = datetime.strptime(text, "%B %d, %Y").date()
            dates.append(str(date))
        except ValueError:
            pass

    return dates


def get_current_slots():
    """Fetch current DFA slots from Supabase."""
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
    """Get all FCM tokens subscribed to DFA."""
    res = requests.get(
        f"{SUPABASE_URL}/rest/v1/subscriptions?agency_id=eq.dfa&select=fcm_token",
        headers=HEADERS
    )
    return [row["fcm_token"] for row in res.json()]


def send_push_notification(tokens, new_dates):
    """Send FCM push to all subscribed tokens."""
    if not tokens:
        print("No subscribers, skipping notification.")
        return

    for token in tokens:
        payload = {
            "to": token,
            "notification": {
                "title": "DFA Slot Available!",
                "body": f"New slots open: {', '.join(new_dates)}",
            },
            "data": {"agency_id": "dfa"}
        }
        res = requests.post(
            "https://fcm.googleapis.com/fcm/send",
            headers={
                "Authorization": f"key={FCM_SERVER_KEY}",
                "Content-Type": "application/json"
            },
            json=payload
        )
        print(f"FCM response for {token[:20]}...: {res.status_code}")


def run():
    print(f"Scraper started at {datetime.now()}")

    # Collect all available dates across all locations
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
        tokens = get_subscribed_tokens()
        send_push_notification(tokens, list(new_dates))
    else:
        print("No new slots found.")

    print("Scraper finished.")


if __name__ == "__main__":
    run()