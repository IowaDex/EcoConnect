"""Probe the live Firestore rules to see which version is actually deployed.

Old rules (commit f96118b)  -> the barangay CAN create user docs and routePlans.
New rules (working copy)    -> only City Hall provisions users, only Iswim /
                               City Hall dispatch routePlans.

Every probe is a create with a throwaway id, cleaned up immediately when it
succeeds, so nothing real is touched.
"""

import json
import os
import time
import urllib.error
import urllib.request

PROJECT = "ecoconnect-ecaf8"
API_KEY = os.environ["FIREBASE_API_KEY"]
BASE = f"https://firestore.googleapis.com/v1/projects/{PROJECT}/databases/(default)/documents"
AUTH = "https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword"
PASSWORD = os.environ.get("ECO_TEST_PASSWORD", "EcoConnect2026")


def post_json(url, payload, token=None):
    data = json.dumps(payload).encode()
    req = urllib.request.Request(url, data=data, method="POST")
    req.add_header("Content-Type", "application/json")
    if token:
        req.add_header("Authorization", f"Bearer {token}")
    try:
        with urllib.request.urlopen(req) as r:
            return r.status, json.loads(r.read() or b"{}")
    except urllib.error.HTTPError as e:
        return e.code, json.loads(e.read() or b"{}")


def request(method, url, token=None, payload=None):
    data = json.dumps(payload).encode() if payload is not None else None
    req = urllib.request.Request(url, data=data, method=method)
    if token:
        req.add_header("Authorization", f"Bearer {token}")
    if payload is not None:
        req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req) as r:
            return r.status, json.loads(r.read() or b"{}")
    except urllib.error.HTTPError as e:
        return e.code, json.loads(e.read() or b"{}")


def login(email):
    status, body = post_json(
        f"{AUTH}?key={API_KEY}",
        {"email": email, "password": PASSWORD, "returnSecureToken": True},
    )
    if status != 200:
        raise SystemExit(f"login failed for {email}: {status} {body}")
    return body["idToken"], body["localId"]


def s(v):
    return {"stringValue": v}


def b(v):
    return {"booleanValue": v}


def probe(label, method, path, token, payload=None, expect_blocked=True):
    status, body = request(method, f"{BASE}/{path}", token, payload)
    verdict = "ALLOWED" if status == 200 else "BLOCKED"
    ok = (verdict == "BLOCKED") == expect_blocked
    print(f"  {label:<52} {status}  {verdict}  {'ok' if ok else '<-- UNEXPECTED'}")
    return status, body


def main():
    stamp = int(time.time())
    bar_token, bar_uid = login("barangay.ecoconnect@gmail.com")
    iswim_token, _ = login("iswim.ecoconnect@gmail.com")
    print(f"barangay uid = {bar_uid}\n")

    print("A. Barangay creating a user doc (old rules: ALLOWED, new: BLOCKED)")
    uid_doc = f"probe_{stamp}"
    st, _ = probe(
        f"create users/{uid_doc} as barangay",
        "POST",
        f"users?documentId={uid_doc}",
        bar_token,
        {"fields": {"role": s("driver"), "accountStatus": s("active")}},
    )
    if st == 200:
        request("DELETE", f"{BASE}/users/{uid_doc}", bar_token)
        print("     cleanup: probe user doc deleted")

    print("\nB. Barangay creating a route plan (old rules: ALLOWED, new: BLOCKED)")
    plan_doc = f"probe_{stamp}"
    st, _ = probe(
        f"create routePlans/{plan_doc} as barangay",
        "POST",
        f"routePlans?documentId={plan_doc}",
        bar_token,
        {"fields": {"driverId": s("x"), "status": s("scheduled"), "adHoc": b(True)}},
    )
    if st == 200:
        request("DELETE", f"{BASE}/routePlans/{plan_doc}", bar_token)
        print("     cleanup: probe plan deleted")

    print("\nC. Iswim creating a route plan (must stay ALLOWED in both)")
    iswim_doc = f"probe_iswim_{stamp}"
    st, _ = probe(
        f"create routePlans/{iswim_doc} as iswim",
        "POST",
        f"routePlans?documentId={iswim_doc}",
        iswim_token,
        {"fields": {"driverId": s("x"), "status": s("scheduled"), "adHoc": b(False)}},
        expect_blocked=False,
    )
    if st == 200:
        request("DELETE", f"{BASE}/routePlans/{iswim_doc}", iswim_token)
        print("     cleanup: probe plan deleted")

    # The barangay update rule: it may review an account, but must not hand out
    # roles. City Hall seeds the throwaway doc so nothing real is touched.
    print("\nD. Barangay updating an account it does not own")
    ch_token, _ = login("cityhall.ecoconnect@gmail.com")
    role_doc = f"probe_roles_{stamp}"
    st, _ = request(
        "POST",
        f"{BASE}/users?documentId={role_doc}",
        ch_token,
        {"fields": {"role": s("driver"), "accountStatus": s("active")}},
    )
    if st != 200:
        raise SystemExit(f"city hall could not seed the probe doc: {st}")
    print(f"  {'city hall seeded users/' + role_doc:<52} 200  ok")

    patch = f"{BASE}/users/{role_doc}?updateMask.fieldPaths=role"
    probe(
        "barangay changes role driver -> user (must be BLOCKED)",
        "PATCH",
        f"users/{role_doc}?updateMask.fieldPaths=role",
        bar_token,
        {"fields": {"role": s("user")}},
    )
    probe(
        "barangay sets accountStatus pending (must be ALLOWED)",
        "PATCH",
        f"users/{role_doc}?updateMask.fieldPaths=accountStatus",
        bar_token,
        {"fields": {"accountStatus": s("pending")}},
        expect_blocked=False,
    )

    status, body = request("DELETE", f"{BASE}/users/{role_doc}", ch_token)
    print(f"  {'cleanup: probe user deleted':<52} {status}")


if __name__ == "__main__":
    main()
