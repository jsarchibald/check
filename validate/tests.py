def check_payload(payload, expected_payload):
    """Checks whether payload is what we expected."""

    status_code = 200
    for item in expected_payload:
        if not (item in payload and payload[item] == expected_payload[item]):
            status_code = 400

    return status_code


def get_payload(org, repo, slug):
    """Gets the expected payload."""

    with open("hello/check.json") as f:
        check50 = f.read()
    with open("hello/style.json") as f:
        style50 = f.read()

    payload = {
        "commit_hash": "e03bee664b4c310579025e494eb086b213c01626",
        "style50": style50,
        "check50": check50
    }

    return payload
