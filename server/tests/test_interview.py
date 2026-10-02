from __future__ import annotations

import json
from pathlib import Path
import sys
from types import SimpleNamespace

import httpx

from resumer_api.config import PRODUCTION_WEB_ORIGINS, Settings

VALID_PAYLOAD = {
    "model": "openai/gpt-oss-20b",
    "targetRole": "Flutter Developer",
    "experienceLevel": "Fresher",
    "interviewType": "technical",
    "questionCount": 3,
}


def _groq_questions_response(count: int = 3) -> httpx.Response:
    questions = [
        {"question": f"Sample question {i + 1}?", "focusArea": "Flutter"}
        for i in range(count)
    ]
    return httpx.Response(
        200,
        json={"choices": [{"message": {"content": json.dumps({"questions": questions})}}]},
    )


def test_interview_returns_app_compatible_payload_from_groq(make_client):
    def handler(request: httpx.Request) -> httpx.Response:
        body = json.loads(request.content)
        assert request.url.host == "api.groq.com"
        assert body["model"] == "openai/gpt-oss-20b"
        assert body["response_format"] == {"type": "json_object"}
        assert "questions" in body["messages"][1]["content"]
        return _groq_questions_response(3)

    with make_client(handler) as client:
        response = client.post("/v1/interview", json=VALID_PAYLOAD)

    assert response.status_code == 200
    body = response.json()
    questions = body["candidates"][0]["content"]["parts"][0]["text"]
    parsed = json.loads(questions)
    assert len(parsed["questions"]) == 3


def test_interview_rejects_when_ai_provider_not_configured(make_client):
    with make_client(groq_api_key="") as client:
        response = client.post("/v1/interview", json=VALID_PAYLOAD)
    assert response.status_code == 503


def test_interview_validates_question_count(make_client):
    with make_client() as client:
        bad_payload = {**VALID_PAYLOAD, "questionCount": 0}
        response = client.post("/v1/interview", json=bad_payload)
    assert response.status_code == 422


def test_interview_surfaces_upstream_timeout(make_client):
    def handler(request: httpx.Request) -> httpx.Response:
        raise httpx.TimeoutException("boom", request=request)

    with make_client(handler) as client:
        response = client.post("/v1/interview", json=VALID_PAYLOAD)
    assert response.status_code == 504


def test_interview_surfaces_upstream_error(make_client):
    def handler(request: httpx.Request) -> httpx.Response:
        raise httpx.ConnectError("boom", request=request)

    with make_client(handler) as client:
        response = client.post("/v1/interview", json=VALID_PAYLOAD)
    assert response.status_code == 502


def test_interview_surfaces_groq_unavailable_response(make_client):
    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(503, json={"error": {"message": "temporarily unavailable"}})

    with make_client(handler) as client:
        response = client.post("/v1/interview", json=VALID_PAYLOAD)
    assert response.status_code == 503
    assert response.json()["error"]["message"] == "temporarily unavailable"


def _wav_bytes() -> bytes:
    return b"RIFF" + (36).to_bytes(4, "little") + b"WAVE" + b"\x00" * 36


def test_transcribe_interview_answer_forwards_wav_to_vibevoice(
    make_client, monkeypatch
):
    class FakeClient:
        def __init__(self, space: str, *, verbose: bool):
            assert space == "ps783286/resmuer"
            assert verbose is False

        def predict(self, audio: str, service_key: str, *, api_name: str) -> str:
            assert Path(audio).read_bytes().startswith(b"RIFF")
            assert service_key == "asr-test-key"
            assert api_name == "/transcribe"
            return "A spoken answer."

    monkeypatch.setitem(
        sys.modules,
        "gradio_client",
        SimpleNamespace(Client=FakeClient, handle_file=lambda path: path),
    )

    with make_client(
        vibevoice_asr_url="ps783286/resmuer",
        vibevoice_asr_api_key="asr-test-key",
    ) as client:
        response = client.post(
            "/v1/interview/transcribe",
            files={"file": ("answer.wav", _wav_bytes(), "audio/wav")},
        )

    assert response.status_code == 200
    assert response.json() == {"text": "A spoken answer."}


def test_transcribe_requires_configured_vibevoice_service(make_client):
    with make_client() as client:
        response = client.post(
            "/v1/interview/transcribe",
            files={"file": ("answer.wav", _wav_bytes(), "audio/wav")},
        )
    assert response.status_code == 503


def test_transcribe_rejects_non_wav_upload(make_client):
    with make_client(
        vibevoice_asr_url="ps783286/resmuer",
        vibevoice_asr_api_key="asr-test-key",
    ) as client:
        response = client.post(
            "/v1/interview/transcribe",
            files={"file": ("answer.wav", b"not a wav", "audio/wav")},
        )
    assert response.status_code == 415


def test_production_vercel_origin_passes_cors_preflight(make_client):
    origin = "https://web-seven-lovat-95.vercel.app"
    with make_client(cors_origins=(origin,)) as client:
        response = client.options(
            "/v1/interview",
            headers={
                "Origin": origin,
                "Access-Control-Request-Method": "POST",
                "Access-Control-Request-Headers": "content-type",
            },
        )

    assert response.status_code == 200
    assert response.headers["access-control-allow-origin"] == origin


def test_production_vercel_origins_are_kept_with_environment_override(monkeypatch):
    monkeypatch.setenv("RESUMER_CORS_ORIGINS", "http://localhost:8080")

    settings = Settings.from_environment()

    assert all(origin in settings.cors_origins for origin in PRODUCTION_WEB_ORIGINS)
    assert "http://localhost:8080" in settings.cors_origins
