from __future__ import annotations

import io
import re
from typing import Any
import zipfile

from ...normalization.skills import normalize_skills
from ...normalization.titles import normalize_job_title
from ...normalization.locations import detect_state_and_city
from ..classifier import DocumentFormat, LayoutClassification
from ..base_provider import ResumeParserProvider
from ..models import (
    CandidateData,
    ParsedCourse,
    ParsedEducation,
    ParsedExperience,
    ParsedProject,
    ProvenanceField,
)


class LocalPipelineProvider(ResumeParserProvider):
    """Local, offline, multi-format structural parser with regex and section analysis."""

    @property
    def provider_name(self) -> str:
        return "local_structural"

    @property
    def is_configured(self) -> bool:
        return True

    async def parse_resume(
        self,
        bytes_data: bytes,
        filename: str,
        layout: LayoutClassification,
    ) -> CandidateData | None:
        raw_text = self.extract_text(bytes_data, layout.format)
        if not raw_text.strip():
            return None

        # Clean text
        text = raw_text.replace("\r\n", "\n").replace("\r", "\n")
        lines = [line.strip() for line in text.split("\n") if line.strip()]

        name = self._extract_name(lines)
        email = self._extract_email(text)
        phone = self._extract_phone(text)
        location = self._extract_location(lines, text)
        headline = self._extract_headline(lines, name)

        sections = self._split_sections(text)

        summary = self._extract_summary(sections)
        skills = self._extract_skills(sections, text)
        experience = self._extract_experience(sections)
        education = self._extract_education(sections)
        projects = self._extract_projects(sections)
        courses = self._extract_courses(sections)

        # Confidence calculation based on extracted fields
        field_count = sum(
            bool(f)
            for f in (
                name,
                email,
                phone,
                location,
                skills,
                experience,
                education,
            )
        )
        confidence = min(0.98, max(0.5, field_count / 7.0))

        return CandidateData(
            name=ProvenanceField(value=name, source="parser", confidence=0.92 if name else 0.0),
            email=ProvenanceField(value=email, source="parser", confidence=0.98 if email else 0.0),
            phone=ProvenanceField(value=phone, source="parser", confidence=0.95 if phone else 0.0),
            location=ProvenanceField(value=location, source="parser", confidence=0.88 if location else 0.0),
            headline=ProvenanceField(value=headline, source="parser", confidence=0.85 if headline else 0.0),
            summary=ProvenanceField(value=summary, source="parser", confidence=0.85 if summary else 0.0),
            skills=[ProvenanceField(value=s, source="parser", confidence=0.90) for s in skills],
            experience=experience,
            education=education,
            projects=projects,
            courses=courses,
            raw_text=text,
            provider_used=self.provider_name,
            overall_confidence=confidence,
            layout_description=layout.description,
        )

    def extract_text(self, data: bytes, fmt: DocumentFormat) -> str:
        if fmt == DocumentFormat.TXT:
            return data.decode("utf-8", errors="ignore")
        elif fmt == DocumentFormat.DOCX:
            return self._extract_docx(data)
        elif fmt == DocumentFormat.PDF:
            return self._extract_pdf(data)
        elif fmt == DocumentFormat.RTF:
            return self._extract_rtf(data)
        else:
            # Fallback text decoding
            try:
                return data.decode("utf-8", errors="ignore")
            except Exception:
                return ""

    def _extract_docx(self, data: bytes) -> str:
        try:
            with zipfile.ZipFile(io.BytesIO(data)) as z:
                if "word/document.xml" in z.namelist():
                    xml_content = z.read("word/document.xml").decode("utf-8", errors="ignore")
                    # Replace tabs and paragraph boundaries with newlines
                    xml_content = re.sub(r"<w:tab\s*/>", "\t", xml_content)
                    xml_content = re.sub(r"</w:p\s*>", "\n", xml_content)
                    xml_content = re.sub(r"<[^>]+>", " ", xml_content)
                    xml_content = (
                        xml_content.replace("&amp;", "&")
                        .replace("&lt;", "<")
                        .replace("&gt;", ">")
                        .replace("&quot;", '"')
                        .replace("&#39;", "'")
                        .replace("&apos;", "'")
                    )
                    return re.sub(r"[ \t]+", " ", xml_content).strip()
        except Exception:
            pass
        return ""

    def _extract_pdf(self, data: bytes) -> str:
        # Extract text streams from unencrypted PDF
        text_parts: list[str] = []
        # Match Parenthesized strings in PDF text operators: (hello) Tj or [(hello)] TJ
        for match in re.finditer(rb"\((.*?)\)\s*(?:Tj|'|\")", data, re.DOTALL):
            raw = match.group(1).decode("latin1", errors="ignore")
            cleaned = re.sub(r"\\[0-9]{3}", "", raw).replace(r"\(", "(").replace(r"\)", ")")
            if cleaned.strip():
                text_parts.append(cleaned.strip())

        # Also check TJ arrays: [ (string1) -10 (string2) ] TJ
        for match in re.finditer(rb"\[(.*?)\]\s*TJ", data, re.DOTALL):
            inner = match.group(1)
            for sub in re.finditer(rb"\((.*?)\)", inner):
                raw = sub.group(1).decode("latin1", errors="ignore")
                cleaned = re.sub(r"\\[0-9]{3}", "", raw).replace(r"\(", "(").replace(r"\)", ")")
                if cleaned.strip():
                    text_parts.append(cleaned.strip())

        if text_parts:
            return " ".join(text_parts)

        # Fallback to plain text scan
        plain = data.decode("latin1", errors="ignore")
        cleaned = re.sub(r"[^\x20-\x7E\n\t]", " ", plain)
        return re.sub(r"\s+", " ", cleaned).strip()

    def _extract_rtf(self, data: bytes) -> str:
        text = data.decode("latin1", errors="ignore")
        text = re.sub(r"\\[a-z0-9]+", " ", text)
        text = re.sub(r"[{}]", " ", text)
        return re.sub(r"\s+", " ", text).strip()

    def _extract_name(self, lines: list[str]) -> str:
        for line in lines[:5]:
            # Avoid contact lines, urls, dates, section headers
            if any(char in line for char in ("@", "http", "www.", "/", "\\", "|", "•")):
                continue
            if re.search(r"\b(resume|curriculum|vitae|page|profile|email|phone)\b", line, re.I):
                continue
            words = line.split()
            if 1 <= len(words) <= 4 and all(w[0].isupper() for w in words if w):
                return line.strip()
        return lines[0] if lines else ""

    def _extract_email(self, text: str) -> str:
        match = re.search(r"\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b", text)
        return match.group(0).strip() if match else ""

    def _extract_phone(self, text: str) -> str:
        match = re.search(r"(?:\+?\d{1,3}[-.\s]?)?\(?\d{3,5}\)?[-.\s]?\d{3,5}[-.\s]?\d{3,5}", text)
        if match:
            candidate = match.group(0).strip()
            digits = re.sub(r"\D", "", candidate)
            if 10 <= len(digits) <= 13:
                return candidate
        return ""

    def _extract_location(self, lines: list[str], full_text: str) -> str:
        # Check Indian states and cities first
        state, city, _ = detect_state_and_city(full_text)
        if city and state:
            return f"{city}, {state}, India"
        if state:
            return f"{state}, India"
        # Check lines 2-5 for City, State / Country format
        for line in lines[1:6]:
            if "," in line and not any(c in line for c in ("@", "http", "www.")):
                parts = [p.strip() for p in line.split(",") if p.strip()]
                if 2 <= len(parts) <= 3:
                    return line.strip()
        return ""

    def _extract_headline(self, lines: list[str], name: str) -> str:
        for line in lines[1:6]:
            if line == name or any(char in line for char in ("@", "http", "phone")):
                continue
            if len(line) < 120 and any(
                kw in line.lower()
                for kw in (
                    "engineer",
                    "developer",
                    "student",
                    "analyst",
                    "designer",
                    "manager",
                    "architect",
                    "intern",
                )
            ):
                return line.strip()
        return ""

    def _split_sections(self, text: str) -> dict[str, str]:
        section_headers = {
            "summary": ["summary", "profile", "about me", "professional summary", "objective"],
            "experience": ["experience", "work experience", "employment", "work history", "professional experience"],
            "education": ["education", "academic background", "qualifications"],
            "skills": ["skills", "technical skills", "skills & expertise", "core competencies", "technologies"],
            "projects": ["projects", "personal projects", "academic projects", "key projects"],
            "courses": ["courses", "certifications", "certificates", "licenses"],
        }

        pattern = r"\n\s*(?:[0-9]+\.\s*)?([A-Z][A-Za-z\s&]{2,30})\s*(?:\n|:)"
        padded_text = "\n" + text
        matches = list(re.finditer(pattern, padded_text))

        sections: dict[str, str] = {}
        for i, match in enumerate(matches):
            raw_title = match.group(1).strip().lower()
            start = match.end()
            end = matches[i + 1].start() if i + 1 < len(matches) else len(padded_text)
            body = padded_text[start:end].strip()

            for sec_key, aliases in section_headers.items():
                if any(alias in raw_title for alias in aliases):
                    sections[sec_key] = body
                    break

        return sections

    def _extract_summary(self, sections: dict[str, str]) -> str:
        raw = sections.get("summary", "")
        return re.sub(r"\s+", " ", raw).strip()

    def _extract_skills(self, sections: dict[str, str], full_text: str) -> list[str]:
        raw_skills = sections.get("skills", "")
        extracted: list[str] = []

        if raw_skills:
            items = re.split(r"[,|\n•\t;]+", raw_skills)
            for item in items:
                clean = item.strip().strip("•-*")
                if clean and len(clean) < 40:
                    extracted.append(clean)

        # If few skills were found, scan full text for common skills
        if len(extracted) < 3:
            common_skills = [
                "Python", "JavaScript", "TypeScript", "React", "Flutter", "Dart",
                "Java", "C++", "Go", "SQL", "PostgreSQL", "Docker", "Kubernetes",
                "AWS", "GCP", "Azure", "Git", "HTML5", "CSS3", "Node.js", "FastAPI"
            ]
            for skill in common_skills:
                if re.search(r"\b" + re.escape(skill) + r"\b", full_text, re.I):
                    extracted.append(skill)

        return normalize_skills(extracted)

    def _extract_experience(self, sections: dict[str, str]) -> list[ParsedExperience]:
        raw = sections.get("experience", "")
        if not raw:
            return []

        entries: list[ParsedExperience] = []
        blocks = re.split(r"\n\s*\n+", raw)

        for block in blocks:
            lines = [l.strip() for l in block.split("\n") if l.strip()]
            if not lines:
                continue

            first_line = lines[0]
            date_match = re.search(
                r"(\b(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s*\d{4}\s*[-–—to]+\s*(?:Present|\b(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s*\d{4}|\d{4})|\b20\d\d\s*[-–—]\s*(?:Present|20\d\d))",
                block,
                re.I,
            )
            date_str = date_match.group(0).strip() if date_match else None

            # Split title and company if separated by comma or pipe
            parts = re.split(r"[,|–—\t]+", first_line)
            title = parts[0].strip()
            company = parts[1].strip() if len(parts) > 1 else "Company"

            bullets = [
                re.sub(r"^[•\-\*\s]+", "", l).strip()
                for l in lines[1:]
                if l.startswith(("•", "-", "*")) or len(l) > 30
            ]

            entries.append(
                ParsedExperience(
                    title=normalize_job_title(title),
                    company=company,
                    date_range=date_str,
                    bullets=bullets[:6],
                )
            )

        return entries

    def _extract_education(self, sections: dict[str, str]) -> list[ParsedEducation]:
        raw = sections.get("education", "")
        if not raw:
            return []

        entries: list[ParsedEducation] = []
        blocks = re.split(r"\n\s*\n+", raw)

        for block in blocks:
            lines = [l.strip() for l in block.split("\n") if l.strip()]
            if not lines:
                continue

            first_line = lines[0]
            year_match = re.search(r"\b20\d\d\s*[-–—]\s*(?:Present|20\d\d)|\b20\d\d\b", block)
            grad_year = year_match.group(0) if year_match else None

            degree = first_line
            school = lines[1] if len(lines) > 1 else "University"

            entries.append(
                ParsedEducation(
                    degree=degree,
                    school=school,
                    graduation=grad_year,
                )
            )

        return entries

    def _extract_projects(self, sections: dict[str, str]) -> list[ParsedProject]:
        raw = sections.get("projects", "")
        if not raw:
            return []

        entries: list[ParsedProject] = []
        blocks = re.split(r"\n\s*\n+", raw)

        for block in blocks:
            lines = [l.strip() for l in block.split("\n") if l.strip()]
            if not lines:
                continue

            title = lines[0]
            bullets = [
                re.sub(r"^[•\-\*\s]+", "", l).strip()
                for l in lines[1:]
                if l.startswith(("•", "-", "*")) or len(l) > 30
            ]

            entries.append(
                ParsedProject(
                    title=title,
                    bullets=bullets[:4],
                )
            )

        return entries

    def _extract_courses(self, sections: dict[str, str]) -> list[ParsedCourse]:
        raw = sections.get("courses", "")
        if not raw:
            return []

        entries: list[ParsedCourse] = []
        lines = [l.strip() for l in raw.split("\n") if l.strip()]

        for line in lines:
            clean = re.sub(r"^[•\-\*\s]+", "", line).strip()
            if clean:
                entries.append(ParsedCourse(title=clean))

        return entries[:6]
