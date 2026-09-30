from __future__ import annotations

import json

import httpx

from .ai_prompts import (
    INTERVIEW_ANALYSIS_RESPONSE_SCHEMA,
    INTERVIEW_ANALYSIS_SYSTEM_INSTRUCTION,
    INTERVIEW_RESPONSE_SCHEMA,
    INTERVIEW_SYSTEM_INSTRUCTION,
    LEARNING_QUESTIONS_INSTRUCTION,
    LEARNING_QUESTIONS_SCHEMA,
    RESPONSE_SCHEMA,
    SYSTEM_INSTRUCTION,
)
from .models import AnalyzeInterviewRequest, InterviewRequest, LearningQuestionsRequest, TailorRequest


class GroqProxy:
    """Server-side Groq chat-completions adapter returning the app's stable JSON envelope."""

    _endpoint = "https://api.groq.com/openai/v1/chat/completions"

    def __init__(self, client: httpx.AsyncClient, api_key: str, model: str) -> None:
        self._client = client
        self._api_key = api_key
        self._model = model

    @property
    def is_configured(self) -> bool:
        return bool(self._api_key)

    async def complete_json(
        self,
        system: str,
        prompt: str,
        *,
        temperature: float = 0.2,
        max_tokens: int = 4096,
    ) -> httpx.Response:
        if not self.is_configured:
            raise RuntimeError("GROQ_API_KEY is not configured on the server")
        response = await self._client.post(
            self._endpoint,
            headers={
                "Authorization": f"Bearer {self._api_key}",
                "Content-Type": "application/json",
            },
            json={
                "model": self._model,
                "messages": [
                    {"role": "system", "content": system + " Return only a JSON object."},
                    {"role": "user", "content": prompt},
                ],
                "temperature": temperature,
                "max_completion_tokens": max_tokens,
                "response_format": {"type": "json_object"},
            },
        )
        if not response.is_success:
            return response
        body = response.json()
        choices = body.get("choices", [])
        message = choices[0].get("message", {}) if choices else {}
        content = message.get("content")
        if not isinstance(content, str) or not content.strip():
            return httpx.Response(
                502, json={"error": {"message": "Groq returned an empty response"}}
            )
        return httpx.Response(
            200,
            json={"candidates": [{"content": {"parts": [{"text": content}]}}]},
            headers={"Content-Type": "application/json"},
        )

    async def tailor(self, request: TailorRequest) -> httpx.Response:
        prompt = (
            f"Return JSON matching this schema:\n{json.dumps(RESPONSE_SCHEMA)}\n"
            f"Input:\n{json.dumps(request.model_dump(by_alias=True), separators=(',', ':'))}"
        )
        return await self.complete_json(SYSTEM_INSTRUCTION, prompt, max_tokens=8192)

    async def generate_learning_questions(self, request: LearningQuestionsRequest) -> httpx.Response:
        prompt = (
            f"Return JSON matching this schema:\n{json.dumps(LEARNING_QUESTIONS_SCHEMA)}\n"
            f"Input:\n{json.dumps(request.model_dump(by_alias=True), separators=(',', ':'))}"
        )
        return await self.complete_json(LEARNING_QUESTIONS_INSTRUCTION, prompt, temperature=0.5)

    async def generate_interview_questions(self, request: InterviewRequest) -> httpx.Response:
        prompt = (
            f"Target role: {request.target_role}\nCandidate experience level: {request.experience_level}\n"
            f"Interview type: {request.interview_type}\nNumber of questions: {request.question_count}\n"
            f"Required JSON shape: {json.dumps(INTERVIEW_RESPONSE_SCHEMA)}"
        )
        return await self.complete_json(INTERVIEW_SYSTEM_INSTRUCTION, prompt, temperature=0.6)

    async def analyze_interview(self, request: AnalyzeInterviewRequest) -> httpx.Response:
        transcript = "\n\n".join(
            f"Q{i}: {entry.question}\nA{i}: {entry.answer.strip() or '(no answer given)'}"
            for i, entry in enumerate(request.transcript, start=1)
        )
        prompt = (
            f"Return JSON matching this schema:\n{json.dumps(INTERVIEW_ANALYSIS_RESPONSE_SCHEMA)}\n"
            f"Target role: {request.target_role}\nInterview type: {request.interview_type}\n"
            f"Transcript:\n{transcript}"
        )
        return await self.complete_json(INTERVIEW_ANALYSIS_SYSTEM_INSTRUCTION, prompt, temperature=0.4, max_tokens=2048)
