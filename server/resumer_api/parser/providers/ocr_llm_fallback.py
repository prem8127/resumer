from __future__ import annotations

import json
import re
from typing import Any

from ..classifier import DocumentFormat, LayoutClassification
from ..base_provider import ResumeParserProvider
from ..models import (
    CandidateData,
    ParsedEducation,
    ParsedExperience,
    ParsedProject,
    ProvenanceField,
)
from ...groq import GroqProxy
from ...normalization.skills import normalize_skills
from ...normalization.titles import normalize_job_title


class OcrLlmFallbackProvider(ResumeParserProvider):
    """Fallback parser using OCR extraction and Groq JSON extraction when primary parsers fail."""

    def __init__(self, ai: GroqProxy | None = None) -> None:
        self._ai = ai

    @property
    def provider_name(self) -> str:
        return "ocr_llm_fallback"

    @property
    def is_configured(self) -> bool:
        return bool(self._ai and self._ai.is_configured)

    async def parse_resume(
        self,
        bytes_data: bytes,
        filename: str,
        layout: LayoutClassification,
    ) -> CandidateData | None:
        raw_text = self._extract_text_or_ocr(bytes_data, layout.format)
        if not raw_text.strip():
            return None

        # If Groq is configured, use JSON extraction
        if self._ai and self._ai.is_configured:
            candidate = await self._extract_with_llm(raw_text, layout)
            if candidate:
                return candidate

        # Basic fallback extraction from text
        return self._extract_heuristic(raw_text, layout)

    def _extract_text_or_ocr(self, data: bytes, fmt: DocumentFormat) -> str:
        # For standard text files
        if fmt in {DocumentFormat.TXT, DocumentFormat.DOCX, DocumentFormat.PDF}:
            try:
                # Basic ASCII/Latin1 string extraction for scanned/raw streams
                strings = re.findall(rb"[\x20-\x7E]{4,}", data)
                return " ".join(s.decode("latin1", errors="ignore") for s in strings)
            except Exception:
                pass
        return data.decode("utf-8", errors="ignore")

    async def _extract_with_llm(
        self, raw_text: str, layout: LayoutClassification
    ) -> CandidateData | None:
        prompt = (
            "You are a specialized ATS resume parser. Extract candidate information from this document text.\n"
            "Return valid JSON ONLY with this structure:\n"
            "{\n"
            '  "name": "...",\n'
            '  "email": "...",\n'
            '  "phone": "...",\n'
            '  "location": "...",\n'
            '  "headline": "...",\n'
            '  "summary": "...",\n'
            '  "skills": ["..."],\n'
            '  "experience": [{"title": "...", "company": "...", "dateRange": "...", "bullets": ["..."]}],\n'
            '  "education": [{"degree": "...", "school": "...", "graduation": "..."}],\n'
            '  "projects": [{"title": "...", "bullets": ["..."]}]\n'
            "}\n\n"
            f"Document Text:\n{raw_text[:12000]}"
        )

        try:
            response = await self._ai.complete_json(
                "Extract candidate information faithfully from the supplied resume text. Never invent facts.",
                prompt,
                temperature=0.1,
                max_tokens=4096,
            )
            if response.status_code != 200:
                return None

            body = response.json()
            candidates = body.get("candidates", [])
            if not candidates:
                return None
            part_text = candidates[0].get("content", {}).get("parts", [{}])[0].get("text", "")
            data = json.loads(part_text)

            return CandidateData(
                name=ProvenanceField(value=data.get("name", ""), source="llm", confidence=0.88),
                email=ProvenanceField(value=data.get("email", ""), source="llm", confidence=0.92),
                phone=ProvenanceField(value=data.get("phone", ""), source="llm", confidence=0.88),
                location=ProvenanceField(value=data.get("location", ""), source="llm", confidence=0.85),
                headline=ProvenanceField(value=data.get("headline", ""), source="llm", confidence=0.85),
                summary=ProvenanceField(value=data.get("summary", ""), source="llm", confidence=0.85),
                skills=[
                    ProvenanceField(value=s, source="llm", confidence=0.85)
                    for s in normalize_skills(data.get("skills", []))
                ],
                experience=[
                    ParsedExperience(
                        title=normalize_job_title(exp.get("title", "")),
                        company=exp.get("company", ""),
                        date_range=exp.get("dateRange"),
                        bullets=exp.get("bullets", []),
                        confidence=0.85,
                    )
                    for exp in data.get("experience", [])
                ],
                education=[
                    ParsedEducation(
                        degree=edu.get("degree", ""),
                        school=edu.get("school", ""),
                        graduation=edu.get("graduation"),
                        confidence=0.85,
                    )
                    for edu in data.get("education", [])
                ],
                projects=[
                    ParsedProject(
                        title=proj.get("title", ""),
                        bullets=proj.get("bullets", []),
                        confidence=0.82,
                    )
                    for proj in data.get("projects", [])
                ],
                courses=[],
                raw_text=raw_text,
                provider_used="groq_llm_fallback",
                overall_confidence=0.85,
                layout_description=layout.description,
            )
        except Exception:
            return None

    def _extract_heuristic(self, text: str, layout: LayoutClassification) -> CandidateData:
        email_match = re.search(r"\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b", text)
        email = email_match.group(0) if email_match else ""

        phone_match = re.search(r"\+?\d[\d -]{8,14}\d", text)
        phone = phone_match.group(0).strip() if phone_match else ""

        return CandidateData(
            name=ProvenanceField(value="Candidate", source="ocr", confidence=0.60),
            email=ProvenanceField(value=email, source="ocr", confidence=0.80 if email else 0.0),
            phone=ProvenanceField(value=phone, source="ocr", confidence=0.75 if phone else 0.0),
            location=ProvenanceField(value="", source="ocr", confidence=0.0),
            headline=ProvenanceField(value="", source="ocr", confidence=0.0),
            summary=ProvenanceField(value="", source="ocr", confidence=0.0),
            skills=[],
            experience=[],
            education=[],
            projects=[],
            courses=[],
            raw_text=text,
            provider_used="ocr_heuristic",
            overall_confidence=0.65,
            layout_description=layout.description,
        )
