import json

from fastapi.testclient import TestClient

from pricing.api import app

client = TestClient(app)
items = [{"sku": "apple", "qty": 3, "unitPrice": 120}, {"sku": "pear", "qty": 1, "unitPrice": 200}]
for discount in ["none", {"percent": {"p": 25}}, {"fixed": {"amount": 1000}}, {"percent": {"p": 150}}]:
    r = client.post("/total", json={"items": items, "discount": discount})
    print(json.dumps(discount), r.status_code, r.json() if r.status_code == 200 else r.json()["detail"][0]["msg"])
r = client.post("/total", json={"items": [{"sku": "x", "qty": 0, "unitPrice": 1}], "discount": "none"})
print("qty 0", r.status_code)
schema = client.get("/openapi.json").json()["components"]["schemas"]["Body_post_total_total_post"]
print(json.dumps(schema["properties"]["discount"]["oneOf"][1], sort_keys=True))
