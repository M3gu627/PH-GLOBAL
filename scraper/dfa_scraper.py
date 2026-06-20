import os
import json
import requests
from datetime import datetime, date
from bs4 import BeautifulSoup
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

BROWSER_HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
    "Accept-Language": "en-US,en;q=0.5",
}


def get_csrf_token(session, html):
    soup = BeautifulSoup(html, "html.parser")
    token = soup.find("input", {"name": "__RequestVerificationToken"})
    return token["value"] if token else None


def create_session():
    """Go through the full DFA appointment flow to get a valid session."""
    session = requests.Session()
    session.headers.update(BROWSER_HEADERS)

    # Step 1: GET homepage
    res = session.get(f"{BASE_URL}/appointment", timeout=15)
    print(f"Step 1 (homepage): {res.status_code}")

    # Step 2: POST terms agreement
    token = get_csrf_token(session, res.text)
    if not token:
        print("ERROR: Could not find CSRF token on homepage")
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
    """For each site, go through site selection then fetch availability."""
    try:
        # Step 3: GET site selection page (should already be there after terms)
        res = session.get(
            f"{BASE_URL}/appointment/individual/schedule",
            timeout=15
        )
        token = get_csrf_token(session, res.text)

        # Step 4: POST site selection + second checkbox
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
            timeout=15
        )
        print(f"  Site selection for {site_name}: {res.status_code}")

        # Step 5: POST to availability API
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
        print(f"  Availability for {site_name}: {res.status_code}, response: {res.text[:100]}")

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