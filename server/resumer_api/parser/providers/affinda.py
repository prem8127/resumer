from __future__ import annotations

import os
from typing import Any
import httpx

from ..classifier import LayoutClassification
from ..base_provider import ResumeParserProvider
from ..models import (
    CandidateData,
    ParsedEducation,
    ParsedExperience,
    ParsedProject,
    ProvenanceField,
)
from ...normalization.skills import normalize_skills


class AffindaParserProvider(ResumeParserProvider):
    """Affinda Resume Parser provider supporting both cloud API and self-hosted container deployments."""

    def __init__(
        self,
        client: httpx.AsyncClient,
        api_key: str | None = None,
        base_url: str | None = None,
    ) -> None:
        self._client = client
        self._api_key = api_key or os.getenv("AFFINDA_API_KEY", "")
        # Defaults to Affinda cloud API or self-hosted container url
        self._base_url = (
            base_url
            or os.getenv("AFFINDA_BASE_URL", "https://api.affinda.com/v3")
        ).rstrip("/")

    @property
    def provider_name(self) -> str:
        return "affinda"

    @property
    def is_configured(self) -> bool:
        return bool(self._api_key or "localhost" in self._base_url or "127.0.0.1" in self._base_url)

    async def parse_resume(
        self,
        bytes_data: bytes,
        filename: str,
        layout: LayoutClassification,
    ) -> CandidateData | None:
        if not self.is_configured:
            return None

        headers = {}
        if self._api_key:
            headers["Authorization"] = f"Bearer {self._api_key}"

        files = {"file": (filename, bytes_data)}
        try:
            response = await self._client.post(
                f"{self._base_url}/documents",
                headers=headers,
                files=files,
                timeout=45.0,
            )
            if response.status_code != 200 and response.status_code != 201:
                return None

            data = response.json().get("data", {})
            return self._map_affinda_to_candidate(data, layout)
        except Exception:
            return None

    def _map_affinda_to_candidate(
        self, data: dict[str, Any], layout: LayoutClassification
    ) -> CandidateData:
        name_val = data.get("name", {}).get("raw", "")
        email_val = (data.get("emails") or [""])[0]
        phone_val = (data.get("phoneNumbers") or [""])[0]
        loc_val = data.get("location", {}).get("formatted", "")
        headline_val = data.get("profession", "") or data.get("summary", "")[:80]
        summary_val = data.get("summary", "")

        raw_skills = [
            s.get("name")
            for s in data.get("skills", [])
            if isinstance(s, dict) and s.get("name")
        ]
        skills = normalize_skills(raw_skills)

        experience = []
        for exp in data.get("workExperience", []):
            if not isinstance(exp, dict):
                continue
            title = exp.get("jobTitle", "") or "Role"
            company = exp.get("organization", "") or "Company"
            dates = exp.get("dates", {})
            start = dates.get("startDate", "")
            end = dates.get("endDate", "Present") if not dates.get("isCurrent") else "Present"
            date_range = f"{start} - {end}" if start else None
            bullets = [
                desc.strip()
                for desc in exp.get("jobDescription", "").split("\n")
                if desc.strip()
            ]
            experience.append(
                ParsedExperience(
                    title=title,
                    company=company,
                    date_range=date_range,
                    bullets=bullets[:6],
                    confidence=0.96,
                )
            )

        education = []
        for edu in data.get("education", []):
            if not isinstance(edu, dict):
                continue
            deg = edu.get("accreditation", {}).get("education", "") or "Degree"
            school = edu.get("organization", "") or "University"
            dates = edu.get("dates", {})
            grad = dates.get("completionDate", "")
            education.append(
                ParsedEducation(
                    degree=deg,
                    school=school,
                    graduation=grad,
                    confidence=0.95,
                )
            )

        return CandidateData(
            name=ProvenanceField(value=name_val, source="affinda", confidence=0.96),
            email=ProvenanceField(value=email_val, source="affinda", confidence=0.98),
            phone=ProvenanceField(value=phone_val, source="affinda", confidence=0.97),
            location=ProvenanceField(value=loc_val, source="affinda", confidence=0.92),
            headline=ProvenanceField(value=headline_val, source="affinda", confidence=0.90),
            summary=ProvenanceField(value=summary_val, source="affinda", confidence=0.90),
            skills=[ProvenanceField(value=s, source="affinda", confidence=0.95) for s in skills],
            experience=experience,
            education=education,
            projects=[],
            courses=[],
            raw_text=data.get("rawText", ""),
            provider_used="affinda",
            overall_confidence=0.95,
            layout_description=layout.description,
        )
