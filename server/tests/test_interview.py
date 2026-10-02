from __future__ import annotations

import json

import httpx

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


def test_transcribe_interview_answer_forwards_wav_to_vibevoice(make_client):
    def handler(request: httpx.Request) -> httpx.Response:
        assert str(request.url) == "https://asr.example/transcribe"
        assert request.headers["authorization"] == "Bearer asr-test-key"
        assert b"answer.wav" in request.content
        assert b"audio/wav" in request.content
        return httpx.Response(200, json={"text": "A spoken answer."})

    with make_client(
        handler,
        vibevoice_asr_url="https://asr.example/transcribe",
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
    with make_client(vibevoice_asr_url="https://asr.example/transcribe") as client:
        response = client.post(
            "/v1/interview/transcribe",
            files={"file": ("answer.wav", b"not a wav", "audio/wav")},
        )
    assert response.status_code == 415
