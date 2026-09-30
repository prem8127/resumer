from __future__ import annotations

import re
import uuid
from typing import Any

from .models import EnrichmentCategory, EnrichmentSuggestion
from ..normalization.skills import normalize_skill
from ..parser.models import CandidateData


class ResumeEnrichmentEngine:
    """Compares external/scraped candidate evidence against the immutable Master Resume

    and produces non-conflicting, user-reviewable enrichment suggestions.
    Master Resume is NEVER automatically modified.
    """

    def generate_suggestions(
        self,
        master: CandidateData,
        external: CandidateData,
        source_label: str = "External / Scraped Resume",
    ) -> list[EnrichmentSuggestion]:
        suggestions: list[EnrichmentSuggestion] = []

        # 1. Skills Comparison
        master_skills_lower = {
            normalize_skill(s.value).lower(): s.value for s in master.skills if s.value.strip()
        }

        for ext_skill in external.skills:
            clean_skill = ext_skill.value.strip()
            if not clean_skill:
                continue
            canonical = normalize_skill(clean_skill)
            canonical_lower = canonical.lower()

            # Rule: only suggest if not already in Master Resume
            if canonical_lower not in master_skills_lower and ext_skill.confidence >= 0.70:
                suggestions.append(
                    EnrichmentSuggestion(
                        id=f"enrich-skill-{uuid.uuid4().hex[:8]}",
                        category=EnrichmentCategory.SKILL,
                        extractedValue=canonical,
                        source=source_label,
                        confidence=round(ext_skill.confidence, 2),
                        foundIn=f"Skills section of {source_label}",
                        reason=f"Skill '{canonical}' was discovered in external evidence but is absent from your Master Resume.",
                    )
                )

        # 2. Projects Comparison
        master_project_titles = {
            self._simplify(p.title) for p in master.projects if p.title.strip()
        }

        for ext_proj in external.projects:
            clean_title = ext_proj.title.strip()
            if not clean_title or ext_proj.confidence < 0.70:
                continue
            simple_title = self._simplify(clean_title)

            if simple_title not in master_project_titles:
                bullets_preview = (
                    f" ({len(ext_proj.bullets)} bullet points)"
                    if ext_proj.bullets
                    else ""
                )
                suggestions.append(
                    EnrichmentSuggestion(
                        id=f"enrich-proj-{uuid.uuid4().hex[:8]}",
                        category=EnrichmentCategory.PROJECT,
                        extractedValue=f"{clean_title}{bullets_preview}",
                        source=source_label,
                        confidence=round(ext_proj.confidence, 2),
                        foundIn=f"Projects section of {source_label}",
                        reason=f"Project '{clean_title}' is present in external data but missing from your Master Resume.",
                    )
                )

        # 3. Education Comparison
        master_education = {
            self._simplify(f"{e.degree} {e.school}")
            for e in master.education
            if e.school.strip() or e.degree.strip()
        }

        for ext_edu in external.education:
            edu_label = f"{ext_edu.degree} - {ext_edu.school}".strip(" -")
            if not edu_label or ext_edu.confidence < 0.70:
                continue
            simple_edu = self._simplify(f"{ext_edu.degree} {ext_edu.school}")

            if simple_edu not in master_education:
                grad = f" ({ext_edu.graduation})" if ext_edu.graduation else ""
                suggestions.append(
                    EnrichmentSuggestion(
                        id=f"enrich-edu-{uuid.uuid4().hex[:8]}",
                        category=EnrichmentCategory.EDUCATION,
                        extractedValue=f"{edu_label}{grad}",
                        source=source_label,
                        confidence=round(ext_edu.confidence, 2),
                        foundIn=f"Education section of {source_label}",
                        reason=f"Education '{edu_label}' was found in external evidence but is absent from your Master Resume.",
                    )
                )

        # 4. Experience Comparison
        master_experience = {
            self._simplify(f"{exp.title} {exp.company}")
            for exp in master.experience
            if exp.company.strip() or exp.title.strip()
        }

        for ext_exp in external.experience:
            exp_label = f"{ext_exp.title} at {ext_exp.company}".strip(" at")
            if not exp_label or ext_exp.confidence < 0.70:
                continue
            simple_exp = self._simplify(f"{ext_exp.title} {ext_exp.company}")

            if simple_exp not in master_experience:
                date_str = f" ({ext_exp.date_range})" if ext_exp.date_range else ""
                suggestions.append(
                    EnrichmentSuggestion(
                        id=f"enrich-exp-{uuid.uuid4().hex[:8]}",
                        category=EnrichmentCategory.EXPERIENCE,
                        extractedValue=f"{exp_label}{date_str}",
                        source=source_label,
                        confidence=round(ext_exp.confidence, 2),
                        foundIn=f"Experience section of {source_label}",
                        reason=f"Experience '{exp_label}' was discovered in external records.",
                    )
                )

        # 5. Certifications / Courses Comparison
        master_courses = {
            self._simplify(c.title) for c in master.courses if c.title.strip()
        }

        for ext_course in external.courses:
            clean_title = ext_course.title.strip()
            if not clean_title or ext_course.confidence < 0.70:
                continue
            simple_title = self._simplify(clean_title)

            if simple_title not in master_courses:
                suggestions.append(
                    EnrichmentSuggestion(
                        id=f"enrich-cert-{uuid.uuid4().hex[:8]}",
                        category=EnrichmentCategory.CERTIFICATION,
                        extractedValue=clean_title,
                        source=source_label,
                        confidence=round(ext_course.confidence, 2),
                        foundIn=f"Certifications of {source_label}",
                        reason=f"Certification/Course '{clean_title}' found in external document.",
                    )
                )

        # 4. Links / Portfolio / GitHub discovery in raw text
        discovered_links = self._extract_links(external.raw_text)
        master_links = self._extract_links(master.raw_text)

        for link in discovered_links:
            if link not in master_links:
                link_type = "GitHub" if "github.com" in link else "LinkedIn" if "linkedin.com" in link else "Portfolio"
                suggestions.append(
                    EnrichmentSuggestion(
                        id=f"enrich-link-{uuid.uuid4().hex[:8]}",
                        category=EnrichmentCategory.LINK,
                        extractedValue=link,
                        source=source_label,
                        confidence=0.95,
                        foundIn=f"Web links of {source_label}",
                        reason=f"Discovered candidate {link_type} link '{link}'.",
                    )
                )

        return suggestions

    def _simplify(self, text: str) -> str:
        return re.sub(r"[^a-zA-Z0-9]", "", text.lower())

    def _extract_links(self, text: str) -> set[str]:
        pattern = r"https?://(?:www\.)?[-a-zA-Z0-9@:%._+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b(?:[-a-zA-Z0-9()@:%_+.~#?&/=]*)"
        matches = re.findall(pattern, text)
        return {
            m.strip().rstrip("/")
            for m in matches
            if any(domain in m for domain in ("github.com", "linkedin.com", "gitlab.com", "portfolio", "behance", "medium"))
        }
