from __future__ import annotations

import base64
import os
from typing import Any
import httpx

from ..classifier import LayoutClassification
from ..base_provider import ResumeParserProvider
from ..models import (
    CandidateData,
    ParsedEducation,
    ParsedExperience,
    ProvenanceField,
)
from ...normalization.skills import normalize_skills


class RChilliParserProvider(ResumeParserProvider):
    """RChilli Resume Parser provider for enterprise taxonomy extraction."""

    def __init__(
        self,
        client: httpx.AsyncClient,
        user_key: str | None = None,
        version: str = "8.0",
    ) -> None:
        self._client = client
        self._user_key = user_key or os.getenv("RCHILLI_USER_KEY", "")
        self._version = version

    @property
    def provider_name(self) -> str:
        return "rchilli"

    @property
    def is_configured(self) -> bool:
        return bool(self._user_key)

    async def parse_resume(
        self,
        bytes_data: bytes,
        filename: str,
        layout: LayoutClassification,
    ) -> CandidateData | None:
        if not self.is_configured:
            return None

        payload = {
            "filedata": base64.b64encode(bytes_data).decode("utf-8"),
            "filename": filename,
            "userkey": self._user_key,
            "version": self._version,
        }

        try:
            response = await self._client.post(
                "https://rest.rchilli.com/RChilli/RChilliParser",
                json=payload,
                timeout=45.0,
            )
            if response.status_code != 200:
                return None
            data = response.json().get("ResumeParserData", {})
            return self._map_rchilli_to_candidate(data, layout)
        except Exception:
            return None

    def _map_rchilli_to_candidate(
        self, data: dict[str, Any], layout: LayoutClassification
    ) -> CandidateData:
        name_val = data.get("Name", {}).get("FormattedName", "")
        email_val = (data.get("Email") or [{}])[0].get("EmailAddress", "")
        phone_val = (data.get("PhoneNumber") or [{}])[0].get("Number", "")
        address = data.get("Address", [{}])[0]
        loc_val = f"{address.get('City', '')}, {address.get('State', '')}".strip(", ")
        headline_val = data.get("CurrentJobProfile", "")
        summary_val = data.get("ExecutiveSummary", "")

        raw_skills = [s.get("Skill", "") for s in data.get("SkillKeywords", []) if s.get("Skill")]
        skills = normalize_skills(raw_skills)

        experience = []
        for exp in data.get("SegregatedExperience", []):
            title = exp.get("JobProfile", {}).get("Title", "") or "Role"
            company = exp.get("Employer", {}).get("EmployerName", "") or "Company"
            start = exp.get("StartDate", "")
            end = exp.get("EndDate", "Present")
            experience.append(
                ParsedExperience(
                    title=title,
                    company=company,
                    date_range=f"{start} - {end}" if start else None,
                    bullets=[exp.get("JobDescription", "")],
                    confidence=0.95,
                )
            )

        education = []
        for edu in data.get("SegregatedQualification", []):
            deg = edu.get("Degree", {}).get("DegreeName", "") or "Degree"
            school = edu.get("Institution", {}).get("Name", "") or "University"
            education.append(
                ParsedEducation(
                    degree=deg,
                    school=school,
                    graduation=edu.get("EndDate", ""),
                    confidence=0.94,
                )
            )

        return CandidateData(
            name=ProvenanceField(value=name_val, source="rchilli", confidence=0.95),
            email=ProvenanceField(value=email_val, source="rchilli", confidence=0.97),
            phone=ProvenanceField(value=phone_val, source="rchilli", confidence=0.96),
            location=ProvenanceField(value=loc_val, source="rchilli", confidence=0.90),
            headline=ProvenanceField(value=headline_val, source="rchilli", confidence=0.90),
            summary=ProvenanceField(value=summary_val, source="rchilli", confidence=0.90),
            skills=[ProvenanceField(value=s, source="rchilli", confidence=0.94) for s in skills],
            experience=experience,
            education=education,
            projects=[],
            courses=[],
            raw_text=data.get("ResumeText", ""),
            provider_used="rchilli",
            overall_confidence=0.94,
            layout_description=layout.description,
        )
