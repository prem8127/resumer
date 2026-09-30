from __future__ import annotations

import json

import httpx


VALID_REQUEST = {
    "courseTitle": "Python Basics",
    "topic": "Functions",
    "context": "Functions package reusable behavior and may accept parameters.",
    "weakTopics": ["default arguments"],
    "count": 3,
    "finalTest": False,
}


def _response() -> httpx.Response:
    questions = [
        {
            "question": "What does a default parameter value provide?",
            "options": ["Fallback argument", "Return type", "Loop condition", "Module name"],
            "correctIndex": 0,
            "topic": "default arguments",
        }
    ]
    return httpx.Response(
        200,
        json={"choices": [{"message": {"content": json.dumps({"questions": questions})}}]},
    )


def test_learning_questions_use_server_groq_proxy(make_client):
    def handler(request: httpx.Request) -> httpx.Response:
        assert request.url.host == "api.groq.com"
        body = json.loads(request.content)
        assert body["response_format"] == {"type": "json_object"}
        assert "untrusted" in body["messages"][0]["content"]
        assert '"questions"' in body["messages"][1]["content"]
        return _response()

    with make_client(
        handler, supabase_token_verifier=lambda token: {"uid": "learner-1"}
    ) as client:
        response = client.post(
            "/v1/learning/questions",
            json=VALID_REQUEST,
            headers={"Authorization": "Bearer test-token"},
        )

    assert response.status_code == 200


def test_learning_questions_reject_invalid_count(make_client):
    with make_client(
        supabase_token_verifier=lambda token: {"uid": "learner-1"}
    ) as client:
        response = client.post(
            "/v1/learning/questions",
            json={**VALID_REQUEST, "count": 0},
            headers={"Authorization": "Bearer test-token"},
        )
    assert response.status_code == 422


def test_learning_questions_requires_server_groq_key(make_client):
    with make_client(
        groq_api_key="",
        supabase_token_verifier=lambda token: {"uid": "learner-1"},
    ) as client:
        response = client.post(
            "/v1/learning/questions",
            json=VALID_REQUEST,
            headers={"Authorization": "Bearer test-token"},
        )
    assert response.status_code == 503


def test_learning_questions_requires_supabase_session(make_client):
    with make_client() as client:
        response = client.post("/v1/learning/questions", json=VALID_REQUEST)
    assert response.status_code == 401


class _Snapshot:
    def __init__(self, value):
        self.value = value
        self.exists = value is not None

    def to_dict(self):
        return self.value


class _Document:
    def __init__(self, store, path):
        self.store = store
        self.path = path

    def collection(self, name):
        return _Collection(self.store, (*self.path, name))

    def document(self, name="generated-attempt"):
        return _Document(self.store, (*self.path, name))

    def get(self):
        return _Snapshot(self.store.records.get(self.path))

    def set(self, data, merge=False):
        if merge and self.path in self.store.records:
            self.store.records[self.path].update(data)
        else:
            self.store.records[self.path] = dict(data)


class _Collection:
    def __init__(self, store, path):
        self.store = store
        self.path = path

    def document(self, name="generated-attempt"):
        return _Document(self.store, (*self.path, name))


class _LearningStore:
    def __init__(self):
        self.records = {
            ("courses", "course-1"): {
                "status": "approved",
                "title": "Python Basics",
                "lessons": [{"id": "lesson-1"}],
            },
            ("courses", "course-1", "private", "finalTest"): {
                "questions": [
                    {
                        "options": ["A", "B", "C", "D"],
                        "correctIndex": 1,
                        "topic": "Functions",
                    },
                    {
                        "options": ["A", "B", "C", "D"],
                        "correctIndex": 2,
                        "topic": "Loops",
                    },
                ],
            },
            ("enrollments", "learner-1", "courses", "course-1"): {
                "done": ["lesson-1"],
            },
        }

    def collection(self, name):
        return _Collection(self, (name,))


def test_final_test_is_graded_and_certificate_is_issued_server_side(make_client):
    store = _LearningStore()
    with make_client(
        supabase_token_verifier=lambda token: {"uid": "learner-1"},
        learning_store_factory=lambda: store,
    ) as client:
        response = client.post(
            "/v1/learning/grade",
            json={"courseId": "course-1", "answers": [1, 2]},
            headers={"Authorization": "Bearer test-token"},
        )

    assert response.status_code == 200
    assert response.json()["score"] == 100
    assert response.json()["passed"] is True
    assert response.json()["certificateId"]
    assert (
        "users", "learner-1", "certificates", "course-1"
    ) in store.records
    assert (
        "enrollments", "learner-1", "courses", "course-1", "attempts",
        "generated-attempt"
    ) in store.records


def test_final_test_rejects_wrong_answer_count(make_client):
    with make_client(
        supabase_token_verifier=lambda token: {"uid": "learner-1"},
        learning_store_factory=_LearningStore,
    ) as client:
        response = client.post(
            "/v1/learning/grade",
            json={"courseId": "course-1", "answers": [1]},
            headers={"Authorization": "Bearer test-token"},
        )

    assert response.status_code == 400


def test_final_test_requires_completed_lessons(make_client):
    store = _LearningStore()
    store.records[("enrollments", "learner-1", "courses", "course-1")][
        "done"
    ] = []
    with make_client(
        supabase_token_verifier=lambda token: {"uid": "learner-1"},
        learning_store_factory=lambda: store,
    ) as client:
        response = client.post(
            "/v1/learning/grade",
            json={"courseId": "course-1", "answers": [1, 2]},
            headers={"Authorization": "Bearer test-token"},
        )

    assert response.status_code == 409
    assert (
        "users", "learner-1", "certificates", "course-1"
    ) not in store.records


def test_final_test_requires_supabase_session(make_client):
    with make_client(learning_store_factory=_LearningStore) as client:
        response = client.post(
            "/v1/learning/grade",
            json={"courseId": "course-1", "answers": [1, 2]},
        )

    assert response.status_code == 401


def test_final_exam_reads_private_supabase_keys_and_issues_certificate(make_client):
    service_headers = []

    def handler(request: httpx.Request) -> httpx.Response:
        service_headers.append(request.headers.get("authorization"))
        if request.method == "GET" and request.url.path.endswith("/courses"):
            return httpx.Response(200, json=[{
                "id": "course-1",
                "status": "approved",
                "data": {"title": "Python Basics", "lessons": [{"id": "lesson-1"}]},
            }])
        if request.method == "GET" and request.url.path.endswith("/test_answer_keys"):
            return httpx.Response(200, json=[{"answers": [{
                "options": ["A", "B", "C", "D"],
                "correctIndex": 1,
                "topic": "Functions",
            }]}])
        if request.method == "GET" and request.url.path.endswith("/enrollments"):
            return httpx.Response(200, json=[{"progress": {"done": ["lesson-1"]}}])
        if request.method == "GET" and request.url.path.endswith("/certificates"):
            return httpx.Response(200, json=[])
        if request.method == "POST" and request.url.path.endswith("/certificates"):
            return httpx.Response(201, json=[{"issued_at": "2026-09-30T12:00:00+00:00"}])
        if request.method == "POST" and request.url.path.endswith("/test_attempts"):
            return httpx.Response(201)
        if request.method == "PATCH" and request.url.path.endswith("/enrollments"):
            return httpx.Response(204)
        return httpx.Response(404)

    with make_client(
        handler,
        supabase_token_verifier=lambda token: {"uid": "learner-1"},
        supabase_service_role_key="server-only-test-key",
    ) as client:
        response = client.post(
            "/v1/learning/grade",
            json={"courseId": "course-1", "answers": [1]},
            headers={"Authorization": "Bearer test-token"},
        )

    assert response.status_code == 200
    assert response.json()["score"] == 100
    assert response.json()["passed"] is True
    assert response.json()["certificateId"].startswith("RES-COURSE-1-")
    assert service_headers and all(value == "Bearer server-only-test-key" for value in service_headers)
