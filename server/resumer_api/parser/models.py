from __future__ import annotations

from typing import Any, Generic, TypeVar
from pydantic import BaseModel, Field

T = TypeVar("T")


class ProvenanceField(BaseModel, Generic[T]):
    """Every extracted field stores its source, confidence, and verification status."""
    value: T
    source: str = "parser"  # master_resume | scraped_resume | parser | llm | user_edit
    confidence: float = 1.0  # 0.0 to 1.0
    verified: bool = False


class ParsedExperience(BaseModel):
    title: str
    company: str
    date_range: str | None = Field(default=None, alias="dateRange")
    location: str | None = None
    bullets: list[str] = Field(default_factory=list)
    confidence: float = 0.95


class ParsedEducation(BaseModel):
    degree: str
    school: str
    graduation: str | None = None
    bullets: list[str] = Field(default_factory=list)
    confidence: float = 0.95


class ParsedProject(BaseModel):
    title: str
    subtitle: str | None = None
    date_range: str | None = Field(default=None, alias="dateRange")
    bullets: list[str] = Field(default_factory=list)
    confidence: float = 0.90


class ParsedCourse(BaseModel):
    title: str
    institution: str | None = None
    date_range: str | None = Field(default=None, alias="dateRange")
    confidence: float = 0.90


class CandidateData(BaseModel):
    """Normalized structured resume candidate output with provenance and confidence."""
    name: ProvenanceField[str] = Field(default_factory=lambda: ProvenanceField(value=""))
    email: ProvenanceField[str] = Field(default_factory=lambda: ProvenanceField(value=""))
    phone: ProvenanceField[str] = Field(default_factory=lambda: ProvenanceField(value=""))
    location: ProvenanceField[str] = Field(default_factory=lambda: ProvenanceField(value=""))
    headline: ProvenanceField[str] = Field(default_factory=lambda: ProvenanceField(value=""))
    summary: ProvenanceField[str] = Field(default_factory=lambda: ProvenanceField(value=""))
    skills: list[ProvenanceField[str]] = Field(default_factory=list)
    experience: list[ParsedExperience] = Field(default_factory=list)
    education: list[ParsedEducation] = Field(default_factory=list)
    projects: list[ParsedProject] = Field(default_factory=list)
    courses: list[ParsedCourse] = Field(default_factory=list)
    raw_text: str = ""
    provider_used: str = "local"
    overall_confidence: float = 0.90
    layout_description: str = ""
