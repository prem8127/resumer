from __future__ import annotations

import base64
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager
from datetime import datetime, timezone
import hashlib
import secrets

from fastapi import (
    Depends,
    FastAPI,
    File,
    Header,
    HTTPException,
    Query,
    Request,
    Response,
    UploadFile,
    status,
)
from fastapi.middleware.cors import CORSMiddleware
import httpx

from .config import Settings
from .enrichment import EnrichmentSuggestion, ResumeEnrichmentEngine
from .groq import GroqProxy
from .models import (
    AnalyzeInterviewRequest,
    EnrichResumeRequest,
    InterviewRequest,
    LearningGradeRequest,
    LearningQuestionsRequest,
    ParseResumeRequest,
    TailorRequest,
)
from .parser import CandidateData, ResumeParsingPipeline


def create_app(
    settings: Settings | None = None,
    *,
    transport: httpx.AsyncBaseTransport | None = None,
    supabase_token_verifier=None,
    learning_store_factory=None,
) -> FastAPI:
    active_settings = settings or Settings.from_environment()

    @asynccontextmanager
    async def lifespan(app: FastAPI) -> AsyncIterator[None]:
        timeout = httpx.Timeout(active_settings.request_timeout_seconds)
        async with httpx.AsyncClient(
            timeout=timeout,
            follow_redirects=True,
            transport=transport,
            headers={"User-Agent": "ResumerAgent/1.0 (+local-development)"},
        ) as client:
            app.state.http = client
            app.state.ai = GroqProxy(client, active_settings.groq_api_key, active_settings.groq_model)
            app.state.pipeline = ResumeParsingPipeline(client, app.state.ai)
            app.state.enrichment = ResumeEnrichmentEngine()
            yield

    app = FastAPI(
        title="Resumer Agent API",
        version="0.2.0",
        description=(
            "Resume parsing, enrichment, interview analysis, and Groq-backed resume tools. "
            "Job discovery is handled by the Flutter JSearch service."
        ),
        lifespan=lifespan,
    )
    app.add_middleware(
        CORSMiddleware,
        allow_origins=list(active_settings.cors_origins),
        allow_origin_regex=active_settings.cors_origin_regex,
        allow_credentials=False,
        allow_methods=["GET", "POST", "OPTIONS"],
        allow_headers=["Authorization", "Content-Type", "X-API-Key"],
    )

    app.state.supabase_token_verifier = supabase_token_verifier
    app.state.learning_store_factory = learning_store_factory

    async def require_supabase_user(
        request: Request,
        authorization: str | None = Header(default=None),
    ) -> dict[str, object]:
        if not authorization or not authorization.startswith("Bearer "):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Supabase sign-in is required",
            )
        token = authorization[7:].strip()
        try:
            verifier = request.app.state.supabase_token_verifier
            if verifier is not None:
                return verifier(token)
            if not active_settings.supabase_url or not active_settings.supabase_publishable_key:
                raise RuntimeError("Supabase Auth is not configured")
            response = await request.app.state.http.get(
                f"{active_settings.supabase_url}/auth/v1/user",
                headers={
                    "apikey": active_settings.supabase_publishable_key,
                    "Authorization": f"Bearer {token}",
                },
            )
            response.raise_for_status()
            user = response.json()
            if not isinstance(user, dict) or not isinstance(user.get("id"), str):
                raise ValueError("Invalid Supabase session")
            return {"uid": user["id"], **user}
        except Exception as error:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid Supabase session",
            ) from error

    async def require_api_key(
        x_api_key: str | None = Header(default=None),
    ) -> None:
        expected = active_settings.api_key
        if expected and (
            x_api_key is None or not secrets.compare_digest(x_api_key, expected)
        ):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Missing or invalid API key",
            )

    async def grade_with_supabase(
        request: Request, uid: str, payload: LearningGradeRequest
    ) -> dict[str, object]:
        if not active_settings.supabase_url or not active_settings.supabase_service_role_key:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Supabase server credentials are not configured",
            )
        root = f"{active_settings.supabase_url}/rest/v1"
        headers = {
            "apikey": active_settings.supabase_service_role_key,
            "Authorization": f"Bearer {active_settings.supabase_service_role_key}",
            "Content-Type": "application/json",
        }
        client: httpx.AsyncClient = request.app.state.http

        async def rows(table: str, params: dict[str, str]) -> list[dict[str, object]]:
            response = await client.get(f"{root}/{table}", params=params, headers=headers)
            response.raise_for_status()
            result = response.json()
            return result if isinstance(result, list) else []

        course_rows = await rows("courses", {
            "id": f"eq.{payload.course_id}", "select": "id,data,status"
        })
        course = course_rows[0] if course_rows else None
        if not course or course.get("status") != "approved":
            raise HTTPException(status_code=404, detail="Published course not found")
        course_data = course.get("data")
        course_data = course_data if isinstance(course_data, dict) else {}
        key_rows = await rows("test_answer_keys", {
            "course_id": f"eq.{payload.course_id}", "test_id": "eq.final", "select": "answers"
        })
        questions = key_rows[0].get("answers") if key_rows else None
        if not isinstance(questions, list) or not questions:
            raise HTTPException(status_code=409, detail="No published final test")
        if len(payload.answers) != len(questions):
            raise HTTPException(status_code=400, detail="Answer count does not match the test")
        enrollment_rows = await rows("enrollments", {
            "user_id": f"eq.{uid}", "course_id": f"eq.{payload.course_id}", "select": "progress"
        })
        if not enrollment_rows:
            raise HTTPException(status_code=403, detail="Enroll in this course first")
        progress = enrollment_rows[0].get("progress")
        progress = dict(progress) if isinstance(progress, dict) else {}
        lessons = course_data.get("lessons", [])
        lesson_ids = {
            lesson.get("id") for lesson in lessons
            if isinstance(lesson, dict) and isinstance(lesson.get("id"), str)
        } if isinstance(lessons, list) else set()
        completed = set(progress.get("done", [])) if isinstance(progress.get("done"), list) else set()
        if not lesson_ids.issubset(completed):
            raise HTTPException(status_code=409, detail="Complete every lesson before the final test")

        weak_topics: list[str] = []
        correct_count = 0
        for answer, question in zip(payload.answers, questions, strict=True):
            if not isinstance(question, dict):
                raise HTTPException(status_code=500, detail="Invalid published test")
            correct_index = question.get("correctIndex")
            options = question.get("options")
            if not isinstance(correct_index, int) or not isinstance(options, list):
                raise HTTPException(status_code=500, detail="Invalid published test")
            if answer < -1 or answer >= len(options):
                raise HTTPException(status_code=400, detail="Answer is outside the option range")
            if answer == correct_index:
                correct_count += 1
            else:
                topic = question.get("topic")
                if isinstance(topic, str) and topic.strip():
                    weak_topics.append(topic.strip()[:120])
        weak_topics = list(dict.fromkeys(weak_topics))[:20]
        score = round(correct_count * 100 / len(questions))
        passed = score >= 60
        issued_at = datetime.now(timezone.utc)
        certificate_code = None
        if passed:
            certificate_code = f"RES-{payload.course_id[:8].upper()}-{hashlib.sha256(uid.encode()).hexdigest()[:8].upper()}"
            cert = await rows("certificates", {
                "user_id": f"eq.{uid}", "course_id": f"eq.{payload.course_id}", "select": "certificate_code,issued_at"
            })
            if cert:
                certificate_code = str(cert[0]["certificate_code"])
                issued_at = datetime.fromisoformat(str(cert[0]["issued_at"]).replace("Z", "+00:00"))
            else:
                response = await client.post(
                    f"{root}/certificates?on_conflict=user_id,course_id",
                    headers={**headers, "Prefer": "resolution=ignore-duplicates,return=representation"},
                    json={
                        "user_id": uid,
                        "course_id": payload.course_id,
                        "score": score,
                        "certificate_code": certificate_code,
                    },
                )
                response.raise_for_status()
                created = response.json()
                if isinstance(created, list) and created:
                    issued_at = datetime.fromisoformat(str(created[0]["issued_at"]).replace("Z", "+00:00"))

        await client.post(
            f"{root}/test_attempts",
            headers={**headers, "Prefer": "return=minimal"},
            json={
                "user_id": uid,
                "course_id": payload.course_id,
                "score": score,
                "question_count": len(questions),
                "weak_topics": weak_topics,
            },
        )
        progress.update({
            "testScore": score,
            "testPassed": passed,
            "attemptCount": int(progress.get("attemptCount", 0)) + 1,
            "weakTopics": weak_topics,
            "updatedAt": issued_at.isoformat(),
        })
        if certificate_code:
            progress.update({"certificateId": certificate_code, "certificateIssuedAt": issued_at.isoformat()})
        updated = await client.patch(
            f"{root}/enrollments?user_id=eq.{uid}&course_id=eq.{payload.course_id}",
            headers={**headers, "Prefer": "return=minimal"},
            json={"progress": progress},
        )
        updated.raise_for_status()
        return {
            "score": score,
            "passed": passed,
            "weakTopics": weak_topics,
            "certificateId": certificate_code,
            "issuedAt": issued_at.isoformat() if certificate_code else None,
        }

    @app.get("/health")
    async def health() -> dict[str, object]:
        return {
            "status": "ok",
            "service": "resumer-agent-api",
            "version": "0.2.0",
            "aiConfigured": bool(active_settings.groq_api_key),
            "supabaseConfigured": bool(
                active_settings.supabase_url
                and active_settings.supabase_publishable_key
                and active_settings.supabase_service_role_key
            ),
        }

    @app.get("/v1/jobs/search")
    async def search_jobs(
        request: Request,
        _user: dict[str, object] = Depends(require_supabase_user),
        query: str = Query(min_length=1, max_length=180),
        cursor: str | None = Query(default=None, max_length=500),
        num_pages: int = Query(default=1, ge=1, le=20),
        country: str | None = Query(default=None, min_length=2, max_length=2),
        date_posted: str | None = Query(default=None),
        work_from_home: bool | None = Query(default=None),
        employment_types: str | None = Query(default=None, max_length=80),
    ) -> dict[str, object]:
        if not active_settings.rapidapi_key:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Job search is not configured on the server",
            )
        if date_posted and date_posted not in {
            "all", "today", "3days", "week", "month"
        }:
            raise HTTPException(status_code=422, detail="Unsupported date filter")
        if employment_types:
            allowed_types = {"FULLTIME", "CONTRACTOR", "PARTTIME", "INTERN"}
            requested_types = {
                value.strip().upper().replace("-", "")
                for value in employment_types.split(",")
                if value.strip()
            }
            if not requested_types or not requested_types.issubset(allowed_types):
                raise HTTPException(status_code=422, detail="Unsupported employment type")
            employment_types = ",".join(sorted(requested_types))

        params = {
            "query": query,
            "num_pages": str(num_pages),
            **({"cursor": cursor} if cursor else {}),
            **({"country": country.lower()} if country else {}),
            **({"date_posted": date_posted} if date_posted else {}),
            **({"work_from_home": str(work_from_home).lower()} if work_from_home is not None else {}),
            **({"employment_types": employment_types} if employment_types else {}),
        }
        try:
            upstream = await request.app.state.http.get(
                "https://jsearch.p.rapidapi.com/search-v2",
                params=params,
                headers={
                    "Accept": "application/json",
                    "X-RapidAPI-Key": active_settings.rapidapi_key,
                    "X-RapidAPI-Host": "jsearch.p.rapidapi.com",
                },
            )
        except httpx.HTTPError as error:
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail="The job search provider is temporarily unavailable",
            ) from error
        if upstream.status_code == 429:
            raise HTTPException(status_code=429, detail="Job search rate limit reached")
        if upstream.status_code in (401, 403):
            raise HTTPException(status_code=503, detail="Job search provider is not configured")
        if upstream.status_code < 200 or upstream.status_code >= 300:
            raise HTTPException(status_code=502, detail="Job search provider failed")
        payload = upstream.json()
        if not isinstance(payload, dict):
            raise HTTPException(status_code=502, detail="Invalid job search response")
        return payload

    # ==================== RESUME PARSING & ENRICHMENT ====================

    @app.post(
        "/v1/resumes/parse",
        response_model=CandidateData,
        dependencies=[Depends(require_api_key)],
    )
    async def parse_resume(
        payload: ParseResumeRequest,
        request: Request,
    ) -> CandidateData:
        try:
            file_bytes = base64.b64decode(payload.file_base64)
        except Exception as error:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid base64 payload",
            ) from error

        pipeline: ResumeParsingPipeline = request.app.state.pipeline
        try:
            return await pipeline.parse(file_bytes, payload.filename)
        except Exception as error:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail=f"Could not parse resume: {error}",
            ) from error

    @app.post(
        "/v1/resumes/enrich",
        response_model=list[EnrichmentSuggestion],
        dependencies=[Depends(require_api_key)],
    )
    async def enrich_resume(
        payload: EnrichResumeRequest,
        request: Request,
    ) -> list[EnrichmentSuggestion]:
        engine: ResumeEnrichmentEngine = request.app.state.enrichment
        return engine.generate_suggestions(
            master=payload.master_candidate,
            external=payload.external_candidate,
            source_label=payload.source_label,
        )

    # ==================== TAILORING PROXY ====================

    @app.post("/v1/tailor", dependencies=[Depends(require_api_key)])
    async def tailor(payload: TailorRequest, request: Request) -> Response:
        ai: GroqProxy = request.app.state.ai
        if not ai.is_configured:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="GROQ_API_KEY is not configured on the server",
            )
        try:
            upstream = await ai.tailor(payload)
        except httpx.TimeoutException as error:
            raise HTTPException(
                status_code=status.HTTP_504_GATEWAY_TIMEOUT,
                detail="AI provider timed out",
            ) from error
        except httpx.HTTPError as error:
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail="Could not reach the AI provider",
            ) from error
        return Response(
            content=upstream.content,
            status_code=upstream.status_code,
            media_type=upstream.headers.get("content-type", "application/json"),
        )

    @app.post("/v1/interview", dependencies=[Depends(require_api_key)])
    async def interview(payload: InterviewRequest, request: Request) -> Response:
        ai: GroqProxy = request.app.state.ai
        if not ai.is_configured:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="GROQ_API_KEY is not configured on the server",
            )
        try:
            upstream = await ai.generate_interview_questions(payload)
        except httpx.TimeoutException as error:
            raise HTTPException(
                status_code=status.HTTP_504_GATEWAY_TIMEOUT,
                detail="AI provider timed out",
            ) from error
        except httpx.HTTPError as error:
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail="Could not reach the AI provider",
            ) from error
        return Response(
            content=upstream.content,
            status_code=upstream.status_code,
            media_type=upstream.headers.get("content-type", "application/json"),
        )

    @app.post("/v1/interview/transcribe", dependencies=[Depends(require_api_key)])
    async def transcribe_interview_answer(
        request: Request,
        file: UploadFile = File(...),
    ) -> dict[str, str]:
        """Forward a short WAV answer to the separately hosted VibeVoice ASR."""
        if not active_settings.vibevoice_asr_url:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="VibeVoice transcription is not configured on the server",
            )
        audio = await file.read(20 * 1024 * 1024 + 1)
        if not audio:
            raise HTTPException(status_code=400, detail="Audio recording is empty")
        if len(audio) > 20 * 1024 * 1024:
            raise HTTPException(status_code=413, detail="Audio recording is too large")
        if not audio.startswith(b"RIFF") or audio[8:12] != b"WAVE":
            raise HTTPException(status_code=415, detail="Expected a WAV recording")

        headers = {}
        if active_settings.vibevoice_asr_api_key:
            headers["Authorization"] = (
                f"Bearer {active_settings.vibevoice_asr_api_key}"
            )
        try:
            upstream = await request.app.state.http.post(
                active_settings.vibevoice_asr_url,
                files={"file": ("answer.wav", audio, "audio/wav")},
                headers=headers,
                timeout=active_settings.vibevoice_asr_timeout_seconds,
            )
        except httpx.TimeoutException as error:
            raise HTTPException(
                status_code=status.HTTP_504_GATEWAY_TIMEOUT,
                detail="VibeVoice transcription timed out",
            ) from error
        except httpx.HTTPError as error:
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail="Could not reach the VibeVoice transcription service",
            ) from error
        if upstream.status_code < 200 or upstream.status_code >= 300:
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail="VibeVoice could not transcribe this recording",
            )
        try:
            payload = upstream.json()
        except ValueError as error:
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail="VibeVoice returned an invalid transcription response",
            ) from error
        text = payload.get("text") if isinstance(payload, dict) else None
        if not isinstance(text, str) or not text.strip():
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="No speech was recognized. Try recording again.",
            )
        return {"text": text.strip()[:8000]}

    @app.post("/v1/learning/questions", dependencies=[Depends(require_supabase_user)])
    async def learning_questions(
        payload: LearningQuestionsRequest, request: Request
    ) -> Response:
        ai: GroqProxy = request.app.state.ai
        if not ai.is_configured:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="GROQ_API_KEY is not configured on the server",
            )
        try:
            upstream = await ai.generate_learning_questions(payload)
        except httpx.TimeoutException as error:
            raise HTTPException(status_code=status.HTTP_504_GATEWAY_TIMEOUT, detail="AI provider timed out") from error
        except httpx.HTTPError as error:
            raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail="Could not reach the AI provider") from error
        return Response(content=upstream.content, status_code=upstream.status_code, media_type=upstream.headers.get("content-type", "application/json"))

    @app.post("/v1/learning/grade", dependencies=[Depends(require_supabase_user)])
    async def grade_learning_test(
        payload: LearningGradeRequest,
        request: Request,
        user: dict[str, object] = Depends(require_supabase_user),
    ) -> dict[str, object]:
        uid = user.get("uid")
        if not isinstance(uid, str) or not uid:
            raise HTTPException(status_code=401, detail="Invalid Supabase session")
        store_factory = request.app.state.learning_store_factory
        if store_factory is None:
            try:
                return await grade_with_supabase(request, uid, payload)
            except HTTPException:
                raise
            except httpx.HTTPError as error:
                raise HTTPException(
                    status_code=status.HTTP_502_BAD_GATEWAY,
                    detail="Could not reach Supabase",
                ) from error
        else:
            store = store_factory()
            increment_attempt = 1

        course_ref = store.collection("courses").document(payload.course_id)
        course_snapshot = course_ref.get()
        course = course_snapshot.to_dict() if course_snapshot.exists else None
        if not course or course.get("status") != "approved":
            raise HTTPException(status_code=404, detail="Published course not found")
        key_snapshot = course_ref.collection("private").document("finalTest").get()
        key_data = key_snapshot.to_dict() if key_snapshot.exists else None
        questions = key_data.get("questions") if key_data else None
        if not isinstance(questions, list) or not questions:
            raise HTTPException(status_code=409, detail="No published final test")
        if len(payload.answers) != len(questions):
            raise HTTPException(status_code=400, detail="Answer count does not match the test")
        enrollment_ref = (
            store.collection("enrollments").document(uid)
            .collection("courses").document(payload.course_id)
        )
        enrollment_snapshot = enrollment_ref.get()
        enrollment = enrollment_snapshot.to_dict() if enrollment_snapshot.exists else None
        if enrollment is None:
            raise HTTPException(status_code=403, detail="Enroll in this course first")
        lessons = course.get("lessons", [])
        lesson_ids = {
            lesson.get("id")
            for lesson in lessons
            if isinstance(lesson, dict) and isinstance(lesson.get("id"), str)
        }
        completed_ids = set(enrollment.get("done", []))
        if not lesson_ids.issubset(completed_ids):
            raise HTTPException(status_code=409, detail="Complete every lesson before the final test")

        weak_topics: list[str] = []
        correct_count = 0
        for answer, question in zip(payload.answers, questions, strict=True):
            if not isinstance(question, dict):
                raise HTTPException(status_code=500, detail="Invalid published test")
            correct_index = question.get("correctIndex")
            options = question.get("options")
            if not isinstance(correct_index, int) or not isinstance(options, list):
                raise HTTPException(status_code=500, detail="Invalid published test")
            if answer < -1 or answer >= len(options):
                raise HTTPException(status_code=400, detail="Answer is outside the option range")
            if answer == correct_index:
                correct_count += 1
            else:
                topic = question.get("topic")
                if isinstance(topic, str) and topic.strip():
                    weak_topics.append(topic.strip()[:120])

        score = round(correct_count * 100 / len(questions))
        passed = score >= 60
        issued_at = datetime.now(timezone.utc)
        certificate_id = None
        attempt_ref = enrollment_ref.collection("attempts").document()
        attempt_ref.set({
            "score": score,
            "questionCount": len(questions),
            "weakTopics": list(dict.fromkeys(weak_topics))[:20],
            "createdAt": issued_at,
            "gradedBy": "server",
        })
        if passed:
            certificate_ref = (
                store.collection("users").document(uid)
                .collection("certificates").document(payload.course_id)
            )
            previous = certificate_ref.get()
            if previous.exists:
                certificate_id = previous.to_dict().get("certificateId")
                issued_at = previous.to_dict().get("issuedAt", issued_at)
            else:
                user_fingerprint = hashlib.sha256(uid.encode()).hexdigest()[:8].upper()
                certificate_id = f"RES-{payload.course_id[:8].upper()}-{user_fingerprint}"
                certificate_ref.set({
                    "certificateId": certificate_id,
                    "courseId": payload.course_id,
                    "courseTitle": str(course.get("title", "Course"))[:200],
                    "issuedAt": issued_at,
                    "score": score,
                })

        enrollment_data: dict[str, object] = {
            "testScore": score,
            "testPassed": passed,
            "attemptCount": increment_attempt,
            "weakTopics": list(dict.fromkeys(weak_topics))[:20],
            "updatedAt": issued_at,
        }
        if certificate_id:
            enrollment_data["certificateId"] = certificate_id
            enrollment_data["certificateIssuedAt"] = issued_at
        enrollment_ref.set(enrollment_data, merge=True)

        return {
            "score": score,
            "passed": passed,
            "weakTopics": list(dict.fromkeys(weak_topics))[:20],
            "certificateId": certificate_id,
            "issuedAt": issued_at.isoformat() if certificate_id else None,
        }

    @app.post("/v1/interview/analyze", dependencies=[Depends(require_api_key)])
    async def analyze_interview(
        payload: AnalyzeInterviewRequest, request: Request
    ) -> Response:
        ai: GroqProxy = request.app.state.ai
        if not ai.is_configured:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="GROQ_API_KEY is not configured on the server",
            )
        try:
            upstream = await ai.analyze_interview(payload)
        except httpx.TimeoutException as error:
            raise HTTPException(
                status_code=status.HTTP_504_GATEWAY_TIMEOUT,
                detail="AI provider timed out",
            ) from error
        except httpx.HTTPError as error:
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail="Could not reach the AI provider",
            ) from error
        return Response(
            content=upstream.content,
            status_code=upstream.status_code,
            media_type=upstream.headers.get("content-type", "application/json"),
        )

    return app


app = create_app()
