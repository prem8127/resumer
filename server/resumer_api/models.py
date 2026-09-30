from __future__ import annotations

from typing import Any

from pydantic import BaseModel, ConfigDict, Field

from .enrichment.models import EnrichmentSuggestion
from .parser.models import CandidateData


class ApiModel(BaseModel):
    model_config = ConfigDict(populate_by_name=True)


class TailorRequest(ApiModel):
    model: str = "openai/gpt-oss-20b"
    job_description: str = Field(alias="jobDescription", min_length=1, max_length=16000)
    career_evidence: list[dict[str, Any]] = Field(
        default_factory=list, alias="careerEvidence"
    )


class InterviewRequest(ApiModel):
    model: str = "openai/gpt-oss-20b"
    target_role: str = Field(alias="targetRole", min_length=1, max_length=200)
    experience_level: str = Field(alias="experienceLevel", min_length=1, max_length=100)
    interview_type: str = Field(alias="interviewType", min_length=1, max_length=50)
    question_count: int = Field(alias="questionCount", ge=1, le=20)


class InterviewTranscriptEntry(ApiModel):
    question: str = Field(min_length=1, max_length=2000)
    answer: str = Field(default="", max_length=8000)


class AnalyzeInterviewRequest(ApiModel):
    model: str = "openai/gpt-oss-20b"
    target_role: str = Field(alias="targetRole", min_length=1, max_length=200)
    interview_type: str = Field(alias="interviewType", min_length=1, max_length=50)
    transcript: list[InterviewTranscriptEntry] = Field(min_length=1, max_length=20)


class LearningQuestionsRequest(ApiModel):
    course_title: str = Field(alias="courseTitle", min_length=1, max_length=200)
    topic: str = Field(min_length=1, max_length=200)
    context: str = Field(default="", max_length=12000)
    count: int = Field(default=5, ge=1, le=15)
    weak_topics: list[str] = Field(default_factory=list, alias="weakTopics", max_length=20)
    final_test: bool = Field(default=False, alias="finalTest")


class LearningGradeRequest(ApiModel):
    course_id: str = Field(alias="courseId", min_length=1, max_length=160)
    answers: list[int] = Field(min_length=1, max_length=50)


class ParseResumeRequest(ApiModel):
    filename: str
    file_base64: str = Field(alias="fileBase64")
    content_type: str | None = Field(default=None, alias="contentType")


class EnrichResumeRequest(ApiModel):
    master_candidate: CandidateData = Field(alias="masterCandidate")
    external_candidate: CandidateData = Field(alias="externalCandidate")
    source_label: str = Field(default="Imported Resume", alias="sourceLabel")
