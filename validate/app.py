from flask import Flask, request
from hashlib import sha512
from tests import check_payload, get_payload

app = Flask(__name__)

@app.route("/validate")
def validate():
    status_code = 400
    if request.is_json:
        signature = request.headers["X-Payload-Signature"]
        payload = request.get_json()

        sha = sha512(request.data).hexdigest()
        if signature == sha:
            expected_payload = get_payload(payload["org"], payload["repo"], payload["slug"])
            status_code = check_payload(payload, expected_payload)

    return "", status_code

