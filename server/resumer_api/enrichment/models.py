from __future__ import annotations

from enum import StrEnum
from pydantic import BaseModel, ConfigDict, Field


class EnrichmentCategory(StrEnum):
    SKILL = "skill"
    PROJECT = "project"
    CERTIFICATION = "certification"
    EDUCATION = "education"
    EXPERIENCE = "experience"
    LINK = "link"
    HEADLINE = "headline"


class SuggestionStatus(StrEnum):
    PENDING = "pending"
    ACCEPTED = "accepted"
    IGNORED = "ignored"


class EnrichmentSuggestion(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    id: str
    category: EnrichmentCategory
    extracted_value: str = Field(alias="extractedValue")
    source: str
    confidence: float
    found_in: str = Field(default="", alias="foundIn")
    reason: str
    status: SuggestionStatus = SuggestionStatus.PENDING
