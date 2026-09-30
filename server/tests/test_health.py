from __future__ import annotations


def test_health_reports_ai_provider_configured(make_client):
    with make_client(groq_api_key="a-key") as client:
        response = client.get("/health")
    assert response.status_code == 200
    body = response.json()
    assert body["status"] == "ok"
    assert body["aiConfigured"] is True


def test_health_reports_ai_provider_not_configured(make_client):
    with make_client(groq_api_key="") as client:
        response = client.get("/health")
    assert response.status_code == 200
    assert response.json()["aiConfigured"] is False
