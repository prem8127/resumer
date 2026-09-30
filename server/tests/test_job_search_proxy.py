from __future__ import annotations

import httpx


def test_job_search_proxy_requires_signed_in_user(make_client):
    client = make_client(lambda request: httpx.Response(200, json={"data": []}))

    response = client.get("/v1/jobs/search", params={"query": "Flutter developer"})

    assert response.status_code == 401


def test_job_search_proxy_keeps_provider_key_server_side(make_client):
    seen: list[httpx.Request] = []

    def handler(request: httpx.Request) -> httpx.Response:
        seen.append(request)
        return httpx.Response(
            200,
            json={"data": {"jobs": [], "cursor": "next-page"}},
        )

    client = make_client(
        handler,
        supabase_token_verifier=lambda token: {"uid": "test-user"},
    )
    with client:
        response = client.get(
            "/v1/jobs/search",
            params={
                "query": "Flutter developer in Pune",
                "num_pages": 2,
                "country": "IN",
                "work_from_home": "true",
            },
            headers={"Authorization": "Bearer valid-session"},
        )

    assert response.status_code == 200
    assert response.json()["data"]["cursor"] == "next-page"
    assert len(seen) == 1
    assert seen[0].url.host == "jsearch.p.rapidapi.com"
    assert seen[0].headers["X-RapidAPI-Key"] == "test-rapidapi-key"
    assert "X-RapidAPI-Key" not in response.text
    assert seen[0].url.params["num_pages"] == "2"


def test_job_search_proxy_rejects_invalid_filters(make_client):
    client = make_client(
        lambda request: httpx.Response(200, json={"data": {"jobs": []}}),
        supabase_token_verifier=lambda token: {"uid": "test-user"},
    )

    response = client.get(
        "/v1/jobs/search",
        params={"query": "Flutter", "date_posted": "whenever"},
        headers={"Authorization": "Bearer valid-session"},
    )

    assert response.status_code == 422
