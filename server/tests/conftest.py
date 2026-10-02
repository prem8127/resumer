from __future__ import annotations

from collections.abc import Callable

import httpx
import pytest
from fastapi.testclient import TestClient

from resumer_api.config import Settings
from resumer_api.main import create_app


def make_settings(
    *,
    groq_api_key: str = "test-groq-key",
    supabase_url: str = "",
    supabase_publishable_key: str = "",
    supabase_service_role_key: str = "",
    rapidapi_key: str = "test-rapidapi-key",
    vibevoice_asr_url: str = "",
    vibevoice_asr_api_key: str = "",
    cors_origins: tuple[str, ...] = (),
) -> Settings:
    return Settings(
        groq_api_key=groq_api_key,
        groq_model="openai/gpt-oss-20b",
        api_key="",
        cors_origins=cors_origins,
        cors_origin_regex=None,
        request_timeout_seconds=5,
        max_concurrency=1,
        supabase_url=supabase_url,
        supabase_publishable_key=supabase_publishable_key,
        supabase_service_role_key=supabase_service_role_key,
        rapidapi_key=rapidapi_key,
        vibevoice_asr_url=vibevoice_asr_url,
        vibevoice_asr_api_key=vibevoice_asr_api_key,
    )


@pytest.fixture
def make_client() -> Callable[..., TestClient]:
    """Builds a TestClient with a mocked upstream Groq transport.

    Pass `handler(request) -> httpx.Response` to control what Groq returns,
    and/or `groq_api_key=""` to simulate an unconfigured server.
    """

    def _make(
        handler: Callable[[httpx.Request], httpx.Response] | None = None,
        *,
        groq_api_key: str = "test-groq-key",
        supabase_token_verifier: Callable[[str], dict[str, object]] | None = None,
        learning_store_factory=None,
        supabase_service_role_key: str = "",
        rapidapi_key: str = "test-rapidapi-key",
        vibevoice_asr_url: str = "",
        vibevoice_asr_api_key: str = "",
        cors_origins: tuple[str, ...] = (),
    ) -> TestClient:
        transport = httpx.MockTransport(
            handler
            or (lambda request: httpx.Response(200, json={"candidates": []}))
        )
        app = create_app(
            settings=make_settings(
                groq_api_key=groq_api_key,
                supabase_url="https://example.supabase.co" if supabase_service_role_key else "",
                supabase_publishable_key="test-publishable" if supabase_service_role_key else "",
                supabase_service_role_key=supabase_service_role_key,
                rapidapi_key=rapidapi_key,
                vibevoice_asr_url=vibevoice_asr_url,
                vibevoice_asr_api_key=vibevoice_asr_api_key,
                cors_origins=cors_origins,
            ),
            transport=transport,
            supabase_token_verifier=supabase_token_verifier,
            learning_store_factory=learning_store_factory,
        )
        return TestClient(app)

    return _make
