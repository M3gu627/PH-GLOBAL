import os
import json
import asyncio
import random
import re
import requests
import time
from playwright.async_api import async_playwright
from supabase import create_client

SUPABASE_URL = os.environ["SUPABASE_URL"]
SUPABASE_KEY = os.environ["SUPABASE_KEY"]

BASE_URL = "https://crs-appointment.psahelpline.ph"
START_URL = f"{BASE_URL}/book/choose-purpose"
COOKIES_FILE = os.path.join(os.path.dirname(__file__), "psa_cookies.json")
OUTLETS_FILE = os.path.join(os.path.dirname(__file__), "psa_outlet_ids.json")
MAILTM_API = "https://api.mail.tm"

DEBUG = False

REGION_MAP = {
    "NCR": "NCR", "BARMM": "BARMM", "CAR": "CAR", "CARAGA": "CARAGA",
    "REGION I": "REGION I", "REGION II": "REGION II", "REGION III": "REGION III",
    "REGION IV-A": "REGION IV-A", "MIMAROPA": "MIMAROPA Region",
    "REGION V": "REGION V", "REGION VI": "REGION VI", "REGION VII": "REGION VII",
    "REGION VIII": "REGION VIII", "REGION IX": "REGION IX", "REGION X": "REGION X",
    "REGION XI": "REGION XI", "REGION XII": "REGION XII",
    "Negros Island Region": "Negros Island Region",
}

with open(OUTLETS_FILE) as f:
    ALL_OUTLETS = [o for o in json.load(f) if "error" not in o]

# Use Muntinlupa (id=5) as first outlet to establish session
FIRST_OUTLET = next(o for o in ALL_OUTLETS if o["outlet_id"] == "5")


def debug(msg):
    if DEBUG:
        print(f"  🐛 DEBUG: {msg}")


def random_ph_mobile():
    """Generate a random valid Philippine mobile number."""
    prefix = random.choice([
        "0917", "0918", "0919", "0920", "0921",
        "0927", "0928", "0929", "0930", "0946",
        "0947", "0948", "0949", "0950", "0956",
        "0961", "0962", "0963", "0973", "0974",
        "0975", "0976", "0977", "0978", "0979",
    ])
    suffix = ''.join([str(random.randint(0, 9)) for _ in range(7)])
    mobile = f"{prefix}{suffix}"
    debug(f"Generated mobile: {mobile}")
    return mobile


# ── Mail.tm ───────────────────────────────────────────────────────────────────

def mailtm_create_inbox():
    debug("Fetching Mail.tm domains...")
    domains = requests.get(f"{MAILTM_API}/domains").json()["hydra:member"]
    domain = domains[0]["domain"]
    debug(f"Using domain: {domain}")

    email = f"phnotify{int(time.time())}@{domain}"
    password = "PHsc4per!2026"

    debug(f"Creating account: {email}")
    reg = requests.post(f"{MAILTM_API}/accounts", json={"address": email, "password": password})
    debug(f"Account creation status: {reg.status_code} — {reg.text[:200]}")
    if reg.status_code not in (200, 201):
        raise Exception(f"Mail.tm account creation failed: {reg.status_code} {reg.text}")

    debug("Waiting 2s for account to be ready...")
    time.sleep(2)

    debug("Requesting token...")
    r = requests.post(f"{MAILTM_API}/token", json={"address": email, "password": password})
    data = r.json()
    debug(f"Token response: {data}")
    if "token" not in data:
        raise Exception(f"Mail.tm token failed: {data}")

    token = data["token"]
    print(f"  📬 Inbox: {email}")
    return email, token


def mailtm_get_otp(token, timeout=90):
    headers = {"Authorization": f"Bearer {token}"}
    deadline = time.time() + timeout
    debug(f"Polling for OTP (timeout={timeout}s)...")
    while time.time() < deadline:
        msgs = requests.get(f"{MAILTM_API}/messages", headers=headers).json().get("hydra:member", [])
        debug(f"Messages in inbox: {len(msgs)}")
        if msgs:
            body = requests.get(f"{MAILTM_API}/messages/{msgs[0]['id']}", headers=headers).json()
            text = body.get("text", "") or body.get("html", "")
            debug(f"Email body preview: {text[:300]}")
            m = re.search(r"\b(\d{6})\b", text)
            if m:
                print(f"  🔑 OTP: {m.group(1)}")
                return m.group(1)
        time.sleep(3)
    raise Exception("OTP timeout")


# ── Cookie helpers ────────────────────────────────────────────────────────────

def load_cookies():
    if os.path.exists(COOKIES_FILE):
        with open(COOKIES_FILE) as f:
            return json.load(f)
    return []


def save_cookies(cookies):
    with open(COOKIES_FILE, "w") as f:
        json.dump(cookies, f, indent=2)
    print("  💾 Cookies saved.")


# ── Page helpers ──────────────────────────────────────────────────────────────

async def livewire_select(page, selector, value=None, index=None):
    el = page.locator(selector)
    if index is not None:
        options = await el.locator("option").all()
        if len(options) > index:
            value = await options[index].get_attribute("value")
    debug(f"Selecting '{value}' in {selector}")
    await el.select_option(value=value)
    await el.dispatch_event("change")
    await page.wait_for_load_state("networkidle")
    await asyncio.sleep(1)


async def click_next(page, timeout=30000):
    debug("Waiting for Next button to be enabled...")
    await page.wait_for_selector(
        "button[wire\\:click='next']:not([disabled])", timeout=timeout
    )
    await asyncio.sleep(0.5)
    debug("Clicking Next button")
    await page.locator("button[wire\\:click='next']").last.click()
    await page.wait_for_load_state("networkidle")
    await asyncio.sleep(1.5)


async def lazy_fill(page, selector, value):
    debug(f"Filling {selector} = '{value}'")
    await page.fill(selector, value)
    await page.locator(selector).dispatch_event("blur")
    await asyncio.sleep(0.5)


async def dump_page_state(page, label):
    if not DEBUG:
        return
    content = await page.content()
    snippet = re.sub(r"<[^>]+>", " ", content)
    snippet = re.sub(r"\s+", " ", snippet).strip()[:500]
    debug(f"--- {label} ---")
    debug(f"URL: {page.url}")
    debug(f"Page snippet: {snippet}")


# ── Handle existing appointment ───────────────────────────────────────────────

async def handle_existing_appointment(page):
    """
    Navigate to the existing appointment page and click OK to dismiss it.
    """
    match = re.search(r'/appointment/(\d+)/existing', page.url)
    booking_id = match.group(1) if match else "21076319"
    existing_url = f"{BASE_URL}/appointment/{booking_id}/existing"

    print(f"  🔄 Navigating to existing appointment page to dismiss it...")
    await page.goto(existing_url, wait_until="networkidle", timeout=30000)
    await asyncio.sleep(2)
    await dump_page_state(page, "Existing appointment page")

    try:
        await page.wait_for_selector("button:has-text('OK')", timeout=5000)
        print("  👆 Clicking OK to dismiss existing appointment...")
        await page.click("button:has-text('OK')")
        await page.wait_for_load_state("networkidle")
        await asyncio.sleep(2)
        print(f"  ✅ Dismissed. Now at: {page.url}")
        await dump_page_state(page, "After OK click")
    except Exception as e:
        debug(f"OK button not found or already dismissed: {e}")


# ── Full initial flow (with OTP) ──────────────────────────────────────────────

async def do_full_flow(page, first_outlet, context, _retry_count=0):
    """
    Returns True  → reached choose-slot (success)
    Returns False → reached wrong page (unexpected failure)
    Retries automatically up to 3 times if existing appointment is detected.
    """
    if _retry_count > 3:
        print("  ❌ Too many retries — giving up.")
        return False

    email, token = mailtm_create_inbox()
    mobile = random_ph_mobile()

    debug(f"Navigating to START_URL: {START_URL}")
    await page.goto(START_URL, wait_until="networkidle", timeout=30000)
    await asyncio.sleep(1)

    content = await page.content()
    if "Restart Appointment" in content:
        debug("Found 'Restart Appointment' — clicking it")
        await page.click("button:has-text('Restart Appointment')")
        await page.wait_for_load_state("networkidle")
        await asyncio.sleep(1)

    # Step 1: Purpose
    print(f"  [1] URL: {page.url}")
    await page.wait_for_selector("select[wire\\:model='purpose']", timeout=15000)
    await livewire_select(page, "select[wire\\:model='purpose']", index=1)
    await click_next(page)

    # Step 2: Region + outlet
    print(f"  [2] URL: {page.url}")
    await page.wait_for_selector("select[wire\\:model='region']", timeout=15000)
    await livewire_select(page, "select[wire\\:model='region']", value=REGION_MAP[first_outlet["region"]])
    await page.wait_for_selector("select[wire\\:model='selected']", timeout=15000)
    await livewire_select(page, "select[wire\\:model='selected']", value=first_outlet["outlet_id"])
    await click_next(page)

    # Step 3: Outlet instructions (some outlets skip straight to contact-info)
    print(f"  [3] URL: {page.url}")
    await dump_page_state(page, "Step 3")
    if "contact-information" not in page.url:
        debug("Not on contact-info yet — clicking Next on instructions page")
        await click_next(page)

    # Step 4: Contact info + inline OTP
    print(f"  [4] URL: {page.url}")
    await dump_page_state(page, "Step 4")
    if "contact-information" in page.url:
        await lazy_fill(page, "input[id='first_name']", "PH")
        await lazy_fill(page, "input[id='last_name']", "Notify")
        await lazy_fill(page, "input[id='email']", email)
        await lazy_fill(page, "input[id='mobile_number']", mobile)
        checkbox = page.locator("input[wire\\:model='agreed']")
        if not await checkbox.is_checked():
            debug("Checking terms checkbox")
            await checkbox.check()
        await asyncio.sleep(1)

        debug("Submitting contact form...")
        await click_next(page)
        await dump_page_state(page, "After contact form submit")

        # Existing appointment detected — dismiss via OK then retry with new mobile
        if "existing" in page.url:
            print(f"  ⚠️  Existing appointment detected (retry {_retry_count + 1}/3) — dismissing...")
            await handle_existing_appointment(page)
            await asyncio.sleep(3)
            if os.path.exists(COOKIES_FILE):
                os.remove(COOKIES_FILE)
                print("  🗑️  Cookies file deleted.")
            await context.clear_cookies()
            return await do_full_flow(page, first_outlet, context, _retry_count + 1)

        # OTP appears inline on the same contact-information page after form submit
        print(f"  [5-OTP] URL: {page.url}")
        try:
            debug("Waiting for OTP input field...")
            await page.wait_for_selector("input[wire\\:model='otp']", timeout=15000)
            print("  🔐 OTP field detected — waiting for email...")
            otp = mailtm_get_otp(token)
            debug(f"Filling OTP: {otp}")
            await page.fill("input[wire\\:model='otp']", otp)
            await page.locator("button:has-text('Verify')").click()
            await page.wait_for_load_state("networkidle")
            await asyncio.sleep(2)
            await dump_page_state(page, "After OTP verify")
        except Exception as e:
            print(f"  ℹ️  OTP field not found (may be skipped by session): {e}")
            await dump_page_state(page, "After OTP timeout")

    # Step 6: Certificates
    print(f"  [6] URL: {page.url}")
    await dump_page_state(page, "Step 6")
    if "certificates" in page.url:
        # Select type by index (first real option)
        await livewire_select(page, "select[wire\\:model\\.lazy='type']", index=1)
        await asyncio.sleep(1)

        # Print available relationship options then select first one
        rel_select = page.locator("select[wire\\:model\\.lazy='relationship']")
        options = await rel_select.locator("option").all()
        option_values = [(await o.get_attribute("value"), await o.inner_text()) for o in options]
        print(f"  📋 Relationship options: {option_values}")
        await livewire_select(page, "select[wire\\:model\\.lazy='relationship']", index=1)
        await asyncio.sleep(2)
        await click_next(page)

    print(f"  [Final] URL: {page.url}")
    await dump_page_state(page, "Final")
    return "choose-slot" in page.url


# ── Get dates ─────────────────────────────────────────────────────────────────

async def get_outlet_dates(page):
    content = await page.content()
    m = re.search(r'"outletDates":\s*(\[[^\]]*\])', content)
    if not m:
        debug("outletDates not found in page content")
        return []
    dates = json.loads(m.group(1))
    debug(f"outletDates found: {dates}")
    return dates


# ── Change outlet ─────────────────────────────────────────────────────────────

async def change_outlet(page, outlet):
    debug(f"Clicking 'Change Outlet' for {outlet['name']}")
    await page.click("button:has-text('Change Outlet')")
    await page.wait_for_load_state("networkidle")
    await asyncio.sleep(1)

    await page.wait_for_selector("select[wire\\:model='region']", timeout=15000)
    await livewire_select(page, "select[wire\\:model='region']", value=REGION_MAP[outlet["region"]])
    await page.wait_for_selector("select[wire\\:model='selected']", timeout=15000)
    await livewire_select(page, "select[wire\\:model='selected']", value=outlet["outlet_id"])
    await click_next(page)

    if "contact-information" not in page.url and "choose-slot" not in page.url:
        try:
            debug("Clicking Next on optional instructions page")
            await click_next(page)
        except Exception as e:
            print(f"  ⚠️  Optional instructions click failed (may be fine): {e}")

    await asyncio.sleep(1)
    print(f"  URL: {page.url}")


# ── Main ──────────────────────────────────────────────────────────────────────

async def main():
    sb = create_client(SUPABASE_URL, SUPABASE_KEY)
    cookies = load_cookies()

    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=True)
        context = await browser.new_context()

        if cookies:
            debug(f"Loading {len(cookies)} saved cookies")
            await context.add_cookies(cookies)

        page = await context.new_page()

        # Check session validity
        await page.goto(START_URL, wait_until="networkidle")
        content = await page.content()
        session_valid = "purpose" in content and "Restart" not in content and cookies
        debug(f"Session valid: {session_valid}")

        on_calendar = False

        if not session_valid:
            print("🔄 No valid session — running full flow with Mail.tm OTP...")
            debug(f"Using first outlet: {FIRST_OUTLET['name']} (id={FIRST_OUTLET['outlet_id']})")

            on_calendar = await do_full_flow(page, FIRST_OUTLET, context)

            if on_calendar:
                save_cookies(await context.cookies())
                dates = await get_outlet_dates(page)
                print(f"[1/{len(ALL_OUTLETS)}] {FIRST_OUTLET['name']} → {dates}")
                if dates:
                    site_id = f"psa_{FIRST_OUTLET['outlet_id']}"
                    rows = [{"agency_id": "psa", "site_id": site_id, "slot_date": d} for d in dates]
                    sb.table("slots").upsert(rows, on_conflict="agency_id,site_id,slot_date").execute()
                remaining = ALL_OUTLETS
            else:
                print("❌ Could not reach calendar. Exiting.")
                await browser.close()
                return
        else:
            print("✅ Session valid — skipping OTP")
            remaining = ALL_OUTLETS

        for i, outlet in enumerate(remaining):
            idx = i + 1
            print(f"[{idx}/{len(ALL_OUTLETS)}] {outlet['name']}")
            try:
                await change_outlet(page, outlet)
                dates = await get_outlet_dates(page)
                print(f"  → {dates}")
                if dates:
                    site_id = f"psa_{outlet['outlet_id']}"
                    rows = [{"agency_id": "psa", "site_id": site_id, "slot_date": d} for d in dates]
                    sb.table("slots").upsert(rows, on_conflict="agency_id,site_id,slot_date").execute()
            except Exception as e:
                print(f"  ❌ {e}")

            await asyncio.sleep(random.uniform(1, 3))

        save_cookies(await context.cookies())
        await browser.close()

    print("Done.")


if __name__ == "__main__":
    asyncio.run(main())