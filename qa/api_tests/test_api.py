import requests

BASE = "http://18.196.175.161:8080")  # GitHub Actions will not substitute; in local runs set env

def test_api_hello():
    r = requests.get(f"{BASE}/api/hello", timeout=5)
    assert r.status_code == 200
    j = r.json()
    assert j.get("message") == "hello"

def test_api_error():
    r = requests.get(f"{BASE}/api/error", timeout=5)
    assert r.status_code == 500
