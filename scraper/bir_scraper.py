import os
import json
import time
import random
import requests
from datetime import datetime, timedelta
from google.oauth2 import service_account
import google.auth.transport.requests

# ---------------------------------------------------------------------------
# BIR Offices — name → mailbox slug
# ---------------------------------------------------------------------------

BIR_OFFICES = {
    "Regular Large Taxpayer Audit Division I": "RegularLargeTaxpayerAuditDivisionIeAppointment@bir.gov.ph",
    "Regular Large Taxpayer Audit Division II": "RegularLargeTaxpayerAuditDivisionIIeAppointment@bir.gov.ph",
    "Regular Large Taxpayer Audit Division III": "RegularLargeTaxpayerAuditDivisionIIIeAppointment@bir.gov.ph",
    "Excise Large Taxpayer Audit Division I": "ExcisteLargeTaxpayerAuditDivisionI@bir.gov.ph",
    "Excise Large Taxpayer Audit Division II": "ExciseLargeTaxpayerAuditDivisionII@bir.gov.ph",
    "Excise LT Field Operations Division": "ExciseLargeTaxpayersFieldOperationsDivisioneAppointment@bir.gov.ph",
    "Excise Large Taxpayer Regulatory Division (ELTRD)": "ExciseLargeTaxpayerRegulatoryDivision@bir.gov.ph",
    "Large Taxpayer Assistance Division (LTAD)": "LargeTaxpayerAssistanceDivisioneAppointmentPortalPage@bir.gov.ph",
    "Large Taxpayer Division Cebu": "LargeTaxpayerDivisionOfficeCebu@bir.gov.ph",
    "Large Taxpayer Division Davao": "RDO127LargeTaxDivisionDavaoeAppointmentPortal@bir.gov.ph",
    "Revenue District Office No. 1": "RDO001AssessmentSectionASeAppointmentPortal@bir.gov.ph",
    "Revenue District Office No. 2": "RDO002AssessmentSectionASeAppointmentPortal@bir.gov.ph",
    "Revenue District Office No. 3": "RDO001AssessmentSectionASeAppointmentPortal1@bir.gov.ph",
    "Revenue District Office No. 4": "RDO04AssessmenteAppointmentPortal@bir.gov.ph",
    "Revenue District Office No. 5": "RDO05AssessmenteAppointmentPortal@bir.gov.ph",
    "Revenue District Office No. 6": "RDO006AssessmentSectionASeAppointmentPortal@bir.gov.ph",
    "Revenue District Office No. 7": "RDO007AssessmentSectionASeAppointmentPortal@bir.gov.ph",
    "Revenue District Office No. 8": "RDO008AssessmentSectionASeAppointmentPortal@bir.gov.ph",
    "Revenue District Office No. 9": "RDO009AssessmentSectionASeAppointmentPortal@bir.gov.ph",
    "Revenue District Office No. 10": "RDO010AssessmentSectionASeAppointmentPortal@bir.gov.ph",
    "Revenue District Office No. 11": "RDO011AssessmentSectionASeAppointmentPortal@bir.gov.ph",
    "Revenue District Office No. 12": "RDO012AssessmentSectionASeAppointmentPortal@bir.gov.ph",
    "Revenue District Office No. 13": "RDO013AssessmentSectionASeAppointmentPortal@bir.gov.ph",
    "Revenue District Office No. 14": "RDO014AssessmentServiceASeAppointmentPortal@bir.gov.ph",
    "Revenue District Office No. 15": "RDO15AssessmentServiceASeAppointmentPortal@bir.gov.ph",
    "Revenue District Office No. 16": "RDO016AssessmentServiceASeAppointmentPortal@bir.gov.ph",
    "Revenue District Office No. 17A": "RDO17AAssessmentServiceASeAppointmentPortal1@bir.gov.ph",
    "Revenue District Office No. 17B": "RDO17BAssessmentServiceASeAppointmentPortal@bir.gov.ph",
    "Revenue District Office No. 18": "RDO018AssessmentServiceASeAppointmentPortal@bir.gov.ph",
    "Revenue District Office No. 19": "RDO019AssessmentServiceASeAppointmentPortal@bir.gov.ph",
    "Revenue District Office No. 20": "RDO020AssessmentServiceASeAppointmentPortal@bir.gov.ph",
    "Revenue District Office No. 21A": "RDO21AAssessmentServiceASeAppoinmentPortal@bir.gov.ph",
    "Revenue District Office No. 21B": "RDO21BAssessmentServiceASeAppointmentPortal@bir.gov.ph",
    "Revenue District Office No. 21C": "RDO21CAssessmentServiceASeAppointmentPortal@bir.gov.ph",
    "Revenue District Office No. 22": "RDO022AssessmentServiceASeAppointmentPortal@bir.gov.ph",
    "Revenue District Office No. 23A": "RDO23AAssessmentServiceASeAppointmentPortal@bir.gov.ph",
    "Revenue District Office No. 23B": "RDO23BAssessmentServiceASeAppointmentPortal@bir.gov.ph",
    "Revenue District Office No. 24": "RDO024AssessmentServiceASeAppointmentPortal@bir.gov.ph",
    "Revenue District Office No. 25A": "RDO25AAssessmentServiceASeAppointmentPortal@bir.gov.ph",
    "Revenue District Office No. 25B": "RDO25BAssessmentServiceASeAppointmentPortal@bir.gov.ph",
    "Revenue District Office No. 26": "RDO026AssessmentServiceASeAppointmentPortal@bir.gov.ph",
    "Revenue District Office No. 27": "RDO027AssessmentServiceASeAppointmentPortal@bir.gov.ph",
    "Revenue District Office No. 28": "RDO028AssessmentServiceASeAppointmentPortal1@bir.gov.ph",
    "Revenue District Office No. 29": "RDO029AssessmentServiceASeAppointmentPortal@bir.gov.ph",
    "Revenue District Office No. 30": "RDO030AssessmentServiceASeAppointmentPortal@bir.gov.ph",
    "Revenue District Office No. 31": "RDO031AssessmentServiceASeAppointmentPortal@bir.gov.ph",
    "Revenue District Office No. 32": "RDO032AssessmentServiceASeAppointmentPortal@bir.gov.ph",
    "Revenue District Office No. 33": "RDO033AssessmentServiceASeAppointmentPortal@bir.gov.ph",
    "Revenue District Office No. 34": "RDO034AssessmentServiceASeAppointmentPortal@bir.gov.ph",
    "Revenue District Office No. 35": "RDO035AssessmentServiceASeAppointmentPortal@bir.gov.ph",
    "Revenue District Office No. 36": "RDO036AssessmentServiceASeAppointmentPortal@bir.gov.ph",
    "Revenue District Office No. 37": "RDO037AssessmentServiceASeAppointmentPortal@bir.gov.ph",
    "Revenue District Office No. 38": "RDO38NorthQuezonCityeAppointment@bir.gov.ph",
    "Revenue District Office No. 39": "RDO039AssessmentServiceASeAppointmentPortal@bir.gov.ph",
    "Revenue District Office No. 40": "RDO040AssessmentServiceASeAppointmentPortal@bir.gov.ph",
    "Revenue District Office No. 41": "RDO041AssessmentServiceASeAppointmentPortal@bir.gov.ph",
    "Revenue District Office No. 42": "RDO042AssessmentServiceASeAppointmentPortal@bir.gov.ph",
    "Revenue District Office No. 43": "RDO043AssessmentServiceASeAppointmentPortal@bir.gov.ph",
    "Revenue District Office No. 44": "RDO044AssessmentServiceASeAppointmentPortal@bir.gov.ph",
    "Revenue District Office No. 45": "RDO045AssessmentServiceASeAppointmentPortal@bir.gov.ph",
    "Revenue District Office No. 46": "RDO046AssessmentServiceASeAppointmentPortal@bir.gov.ph",
    "Revenue District Office No. 47": "RDO047AssessmentServiceASeAppointmentPortal@bir.gov.ph",
    "Revenue District Office No. 48": "RDO048AssessmentServiceASeAppointmentPortal@bir.gov.ph",
    "Revenue District Office No. 49": "RDO049AssessmentServiceASeAppointmentPortal@bir.gov.ph",
    "Revenue District Office No. 50": "RDO050AssessmentServiceASeAppointmentPortal@bir.gov.ph",
    "Revenue District Office No. 51": "RDO051AssessmentServiceASeAppointmentPortal@bir.gov.ph",
    "Revenue District Office No. 52": "RDO052CollectionSectionCSeAppointmentPortalCopy@bir.gov.ph",
    "Revenue District Office No. 53A": "RDO53AAssessmentServiceASeAppointmentPortal@bir.gov.ph",
    "Revenue District Office No. 53B": "RDO53BAssessmentServiceASeAppointmentPortal@bir.gov.ph",
    "Revenue District Office No. 54A": "RDO54AAssessmentServiceASeAppointmentPortal@bir.gov.ph",
    "Revenue District Office No. 54B": "RDO54BAssessmentServiceASeAppointmentPortal@bir.gov.ph",
    "Revenue District Office No. 55": "RDO055AssessmentServiceASeAppointmentPortal@bir.gov.ph",
    "Revenue District Office No. 56": "RDO056AssessmentServiceASeAppointmentPortal@bir.gov.ph",
    "Revenue District Office No. 57": "RDO057AssessmentServiceASeAppointmentPortal@bir.gov.ph",
    "Revenue District Office No. 58": "RDO058AssessmentServiceASeAppointmentPortal@bir.gov.ph",
    "Revenue District Office No. 59": "RDO059AssessmentSectionASeAppointmentPortal@bir.gov.ph",
    "Revenue District Office No. 60": "RDO060AssessmentServiceASeAppointmentPortal@bir.gov.ph",
    "Revenue District Office No. 61": "RDO061AssessmentServiceASeAppointmentPortal@bir.gov.ph",
    "Revenue District Office No. 62": "RDO062AssessmentServiceASeAppointmentPortal1@bir.gov.ph",
    "Revenue District Office No. 63": "RDO063AssessmentServiceASeAppointmentPortal@bir.gov.ph",
    "Revenue District Office No. 64": "RDO064AssessmentServiceASeAppointmentPortal@bir.gov.ph",
    "Revenue District Office No. 65": "RDO065AssessmentServiceASeAppointmentPortal@bir.gov.ph",
    "Revenue District Office No. 66": "RDO066AssessmentServiceASeAppointmentPortal@bir.gov.ph",
    "Revenue District Office No. 67": "RDO067AssessmentServiceASeAppointmentPortal@bir.gov.ph",
    "Revenue District Office No. 68": "RDO068AssessmentServiceASeAppointmentPortal@bir.gov.ph",
    "Revenue District Office No. 69": "RDO069AssessmentServiceASeAppointmentPortal@bir.gov.ph",
    "Revenue District Office No. 70": "RDO070AssessmentServiceASeAppointmentPortal@bir.gov.ph",
    "Revenue District Office No. 71": "RDO071AssessmentServiceASeAppointmentPortal@bir.gov.ph",
    "Revenue District Office No. 72": "RDO072AssessmentServiceASeAppointmentPortal@bir.gov.ph",
    "Revenue District Office No. 73": "RDO073AssessmentServiceASeAppointmentPortal@bir.gov.ph",
    "Revenue District Office No. 74": "RDO074AssessmentServiceASeAppointmentPortal@bir.gov.ph",
    "Revenue District Office No. 75": "RDO075AssessmentServiceASeAppointmentPortal@bir.gov.ph",
    "Revenue District Office No. 76": "RDO076AssessmentServiceASeAppointmentPortal@bir.gov.ph",
    "Revenue District Office No. 77": "RDO077AssessmentServiceASeAppointmentPortal@bir.gov.ph",
    "Revenue District Office No. 78": "RDO078AssessmentServiceASeAppointmentPortal@bir.gov.ph",
    "Revenue District Office No. 79": "RDO079AssessmentServiceASeAppointmentPortal@bir.gov.ph",
    "Revenue District Office No. 80": "RDO080AssessmentServiceASeAppointmentPortal@bir.gov.ph",
    "Revenue District Office No. 81": "RDO081AssessmentServiceASeAppointmentPortal@bir.gov.ph",
    "Revenue District Office No. 82": "RDO082AssessmentServiceASeAppointmentPortal@bir.gov.ph",
    "Revenue District Office No. 83": "RDO83AssessmentServiceASeAppointmentPortal@bir.gov.ph",
    "Revenue District Office No. 84": "RDO84TagbilaranCityBoholeAppointment@bir.gov.ph",
    "Revenue District Office No. 85": "RDO085AssessmentServiceASeAppointmentPortal@bir.gov.ph",
    "Revenue District Office No. 86": "RDO086AssessmentServiceASeAppointmentPortal@bir.gov.ph",
    "Revenue District Office No. 87": "RDO087AssessmentServiceASeAppointmentPortal@bir.gov.ph",
    "Revenue District Office No. 88": "RDO088AssessmentServiceASeAppointmentPortal@bir.gov.ph",
    "Revenue District Office No. 89": "RDO089AssessmentServiceASeAppointmentPortal@bir.gov.ph",
    "Revenue District Office No. 90": "RDO090AssessmentServiceASeAppointmentPortal@bir.gov.ph",
    "Revenue District Office No. 91": "RDO091AssessmentServiceASeAppointmentPortal@bir.gov.ph",
    "Revenue District Office No. 92": "RDO092AssessmentServiceCSeAppointmentPortal1@bir.gov.ph",
    "Revenue District Office No. 93A": "RDO93AAssessmentServiceASeAppointmentPortal@bir.gov.ph",
    "Revenue District Office No. 93B": "RDO93BAssessmentServiceASeAppointmentPortal@bir.gov.ph",
    "Revenue District Office No. 94": "RDO094AssessmentServiceASeAppointmentPortal@bir.gov.ph",
    "Revenue District Office No. 95": "RDO095AssessmentServiceASeAppointmentPortal@bir.gov.ph",
    "Revenue District Office No. 96": "RDO096AssessmentServiceASeAppointmentPortal@bir.gov.ph",
    "Revenue District Office No. 97": "RDO097AssessmentServiceASeAppointmentPortal@bir.gov.ph",
    "Revenue District Office No. 98": "RDO098AssessmentServiceASeAppointmentPortal@bir.gov.ph",
    "Revenue District Office No. 99": "RDO099AssessmentServiceASeAppointmentPortal@bir.gov.ph",
    "Revenue District Office No. 100": "RDO100AssessmentServiceASeAppointmentPortal@bir.gov.ph",
    "Revenue District Office No. 101": "RDO101AssessmentServiceASeAppointmentPortal@bir.gov.ph",
    "Revenue District Office No. 102": "RDO102AssessmentServiceASeAppointmentPortal@bir.gov.ph",
    "Revenue District Office No. 103": "RDO103AssessmentSectionASeAppointmentPortal1@bir.gov.ph",
    "Revenue District Office No. 104": "RDO104AssessmentSectionASeAppointmentPortal@bir.gov.ph",
    "Revenue District Office No. 105": "RDO105AssessmentSectionASeAppointmentPortal@bir.gov.ph",
    "Revenue District Office No. 106": "RDO106AssessmentSectionASeAppointmentPortal@bir.gov.ph",
    "Revenue District Office No. 107": "RDO107AssessmentSectionASeAppointmentPortal@bir.gov.ph",
    "Revenue District Office No. 108": "RDO108AssessmentSectionASeAppointmentPortal@bir.gov.ph",
    "Revenue District Office No. 109": "RDO109AssessmentSectionASeAppointmentPortal@bir.gov.ph",
    "Revenue District Office No. 110": "RDO110AssessmentSectionASeAppointmentPortal@bir.gov.ph",
    "Revenue District Office No. 111": "RDO111AssessmentSectionASeAppointmentPortal@bir.gov.ph",
    "Revenue District Office No. 112": "RDO112AssessmentSectionASeAppointmentPortal@bir.gov.ph",
    "Revenue District Office No. 113A": "RDO113AAssessmentServiceASeAppointmentPortal@bir.gov.ph",
    "Revenue District Office No. 113B": "RDO113BAssessmentSectionASeAppointmentPortal@bir.gov.ph",
    "Revenue District Office No. 114": "RDO114AssessmentSectionASeAppointmentPortal@bir.gov.ph",
    "Revenue District Office No. 115": "RDO115AssessmentSectionASeAppointmentPortal@bir.gov.ph",
}

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------

BOOKINGS_API = "https://bookings.cloud.microsoft/BookingsService/api/V1/bookingBusinessesc2"
SUPABASE_URL = os.environ["SUPABASE_URL"]
SUPABASE_KEY = os.environ["SUPABASE_KEY"]
FCM_SERVICE_ACCOUNT = json.loads(os.environ["FCM_SERVICE_ACCOUNT"])
PROJECT_ID = "ph-global"

BATCH_INDEX = int(os.environ.get("BATCH_INDEX", "0"))
BATCH_TOTAL = int(os.environ.get("BATCH_TOTAL", "1"))

SUPABASE_HEADERS = {
    "apikey": SUPABASE_KEY,
    "Authorization": f"Bearer {SUPABASE_KEY}",
    "Content-Type": "application/json",
}

# ---------------------------------------------------------------------------
# Microsoft Bookings API helpers
# ---------------------------------------------------------------------------

MAX_RETRIES = 3
RETRY_DELAY = 10  # seconds, multiplied by attempt number
REQUEST_DELAY = 2 # seconds between offices


def _post_with_retry(url: str, payload: dict, label: str) -> dict:
    for attempt in range(1, MAX_RETRIES + 1):
        try:
            res = requests.post(url, json=payload, timeout=15)
            return res.json()
        except Exception as e:
            print(f"    {label} timeout (attempt {attempt}/{MAX_RETRIES}): {type(e).__name__}")
            if attempt < MAX_RETRIES:
                time.sleep(RETRY_DELAY * attempt)
    return {}


def get_services(mailbox: str) -> list[dict]:
    url = f"{BOOKINGS_API}/{mailbox}/services"
    payload = {"queryOptions": {"filter": {"or": {"filters": [
        {"attributeFilter": {"attributeName": "BookingServiceCategory", "operator": "FILTER_OPERATOR_TYPE_EQUAL", "stringValue": "BOOKING_SERVICE_CATEGORY_SCHEDULED"}},
        {"attributeFilter": {"attributeName": "BookingServiceCategory", "operator": "FILTER_OPERATOR_TYPE_EQUAL", "stringValue": "BOOKING_SERVICE_CATEGORY_ON_DEMAND"}},
    ]}}}}
    data = _post_with_retry(url, payload, "services")
    return [
        {"serviceId": s["serviceId"], "staffMemberIds": s.get("staffMemberIds", []), "title": s.get("title", "")}
        for s in data.get("service", [])
        if not s.get("isHiddenFromCustomers", False)
    ]


def get_available_dates(mailbox: str, service_id: str, staff_ids: list[str]) -> list[str]:
    url = f"{BOOKINGS_API}/{mailbox}/GetStaffAvailability"
    start = datetime.utcnow().replace(hour=0, minute=0, second=0, microsecond=0)
    end = start + timedelta(days=30)
    payload = {
        "serviceId": service_id,
        "staffIds": staff_ids,
        "startDateTime": {"dateTime": start.strftime("%Y-%m-%dT%H:%M:%S"), "timeZone": "Singapore Standard Time"},
        "endDateTime": {"dateTime": end.strftime("%Y-%m-%dT%H:%M:%S"), "timeZone": "Singapore Standard Time"},
    }
    data = _post_with_retry(url, payload, "availability")
    dates = set()
    for staff in data.get("staffAvailabilityResponse", []):
        for item in staff.get("availabilityItems", []):
            if item.get("status") == "BOOKINGSAVAILABILITYSTATUS_AVAILABLE":
                dates.add(item["startDateTime"]["dateTime"][:10])
    return sorted(dates)

# ---------------------------------------------------------------------------
# Supabase helpers
# ---------------------------------------------------------------------------

def get_active_office_ids() -> set[str]:
    res = requests.get(
        f"{SUPABASE_URL}/rest/v1/subscriptions?agency_id=eq.bir&select=site_id",
        headers=SUPABASE_HEADERS,
    )
    return {row["site_id"] for row in res.json()}


def get_current_slots() -> set[tuple]:
    res = requests.get(
        f"{SUPABASE_URL}/rest/v1/slots?agency_id=eq.bir&select=site_id,slot_date",
        headers=SUPABASE_HEADERS,
    )
    return {(row["site_id"], row["slot_date"]) for row in res.json()}


def insert_slot(site_id: str, date_str: str):
    requests.post(
        f"{SUPABASE_URL}/rest/v1/slots",
        headers=SUPABASE_HEADERS,
        json={"agency_id": "bir", "slot_date": date_str, "site_id": site_id},
    )
    print(f"  Inserted: {date_str} ({site_id})")


def delete_slot(site_id: str, date_str: str):
    requests.delete(
        f"{SUPABASE_URL}/rest/v1/slots?agency_id=eq.bir&slot_date=eq.{date_str}&site_id=eq.{site_id}",
        headers=SUPABASE_HEADERS,
    )
    print(f"  Deleted: {date_str} ({site_id})")


def get_subscribed_tokens(site_id: str) -> list[str]:
    res = requests.get(
        f"{SUPABASE_URL}/rest/v1/subscriptions?agency_id=eq.bir&site_id=eq.{site_id}&select=fcm_token",
        headers=SUPABASE_HEADERS,
    )
    return [row["fcm_token"] for row in res.json()]

# ---------------------------------------------------------------------------
# FCM helpers
# ---------------------------------------------------------------------------

def get_fcm_token() -> str:
    credentials = service_account.Credentials.from_service_account_info(
        FCM_SERVICE_ACCOUNT,
        scopes=["https://www.googleapis.com/auth/firebase.messaging"],
    )
    credentials.refresh(google.auth.transport.requests.Request())
    return credentials.token


def send_push(tokens: list[str], office_name: str, dates: list[str], access_token: str):
    if not tokens:
        return
    url = f"https://fcm.googleapis.com/v1/projects/{PROJECT_ID}/messages:send"
    headers = {"Authorization": f"Bearer {access_token}", "Content-Type": "application/json"}
    for token in tokens:
        payload = {"message": {
            "token": token,
            "notification": {
                "title": "BIR Slot Available!",
                "body": f"{office_name}: {', '.join(dates)}",
            },
            "data": {"agency_id": "bir"},
        }}
        res = requests.post(url, headers=headers, json=payload)
        print(f"  FCM {token[:20]}...: {res.status_code}")

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def run():
    print(f"BIR scraper started at {datetime.now()} | batch {BATCH_INDEX + 1}/{BATCH_TOTAL}")

    offices = list(BIR_OFFICES.items())
    random.shuffle(offices)
    batch_offices = offices[BATCH_INDEX::BATCH_TOTAL]

    active_ids = get_active_office_ids()
    if active_ids:
        batch_offices = [(name, mailbox) for name, mailbox in batch_offices if mailbox in active_ids]
        print(f"  After subscriber filter: {len(batch_offices)} offices")
    else:
        print(f"  No subscribers yet — scraping {len(batch_offices)} offices")

    if not batch_offices:
        print("  Nothing to scrape. Exiting.")
        return

    current_slots = get_current_slots()
    scraped_slots: dict[str, list[str] | None] = {}

    for name, mailbox in batch_offices:
        print(f"\n  {name}")
        services = get_services(mailbox)
        if not services:
            print("    No services found — skipping")
            scraped_slots[mailbox] = None  # None = failed, [] = no slots
            continue

        # Collect available dates across all services
        all_dates: set[str] = set()
        for svc in services:
            dates = get_available_dates(mailbox, svc["serviceId"], svc["staffMemberIds"])
            all_dates.update(dates)

        scraped_slots[mailbox] = sorted(all_dates)
        print(f"    {len(all_dates)} available dates: {sorted(all_dates) or 'none'}")
        time.sleep(random.uniform(0.5, 2.0))

    # Diff against Supabase
    batch_mailboxes = {mailbox for _, mailbox in batch_offices}
    current_for_batch = {(sid, d) for sid, d in current_slots if sid in batch_mailboxes}
    scraped_set = {(mailbox, d) for mailbox, dates in scraped_slots.items() if dates for d in dates}

    new_slots = scraped_set - current_for_batch
    removed_slots = current_for_batch - scraped_set

    for mailbox, d in new_slots:
        insert_slot(mailbox, d)
    for mailbox, d in removed_slots:
        delete_slot(mailbox, d)

    # FCM push
    if new_slots:
        access_token = get_fcm_token()
        notified: set[str] = set()
        office_map = {mailbox: name for name, mailbox in BIR_OFFICES.items()}
        for mailbox, _ in new_slots:
            if mailbox in notified:
                continue
            tokens = get_subscribed_tokens(mailbox)
            if tokens:
                new_dates = [d for m, d in new_slots if m == mailbox]
                send_push(tokens, office_map.get(mailbox, mailbox), new_dates, access_token)
            notified.add(mailbox)

    # Summary
    total = len(batch_offices)
    succeeded  = sum(1 for m, dates in scraped_slots.items() if dates is not None and len(dates) > 0)
    no_slots   = sum(1 for m, dates in scraped_slots.items() if dates is not None and len(dates) == 0)
    failed     = sum(1 for m, dates in scraped_slots.items() if dates is None)
    skipped    = total - len(scraped_slots)
    total_dates = sum(len(d) for d in scraped_slots.values() if d)

    print(f"\n{'='*60}")
    print(f"  BATCH {BATCH_INDEX + 1}/{BATCH_TOTAL} SUMMARY")
    print(f"{'='*60}")
    print(f"  Offices in batch : {total}")
    print(f"  ✓ Had slots      : {succeeded}")
    print(f"  ○ No slots       : {no_slots}")
    print(f"  ✗ Failed/timeout : {failed + skipped}")
    print(f"  Total slot dates : {total_dates}")
    print(f"  New inserted     : {len(new_slots)}")
    print(f"  Removed          : {len(removed_slots)}")
    print(f"  Notifications    : {'sent' if new_slots else 'none'}")
    print(f"{'='*60}")
    print(f"  Finished at {datetime.now()}")
    print(f"{'='*60}\n")


if __name__ == "__main__":
    run()