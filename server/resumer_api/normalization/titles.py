from __future__ import annotations

import re

# Standard occupational taxonomy mapping: maps variations into canonical role categories
_TITLE_TAXONOMY: dict[str, str] = {
    # Software Engineering
    "software developer": "Software Engineer",
    "software engineer": "Software Engineer",
    "application developer": "Software Engineer",
    "applications developer": "Software Engineer",
    "programmer": "Software Engineer",
    "swe": "Software Engineer",
    "sde": "Software Engineer",
    "sde 1": "Software Engineer",
    "sde i": "Software Engineer",
    "sde 2": "Senior Software Engineer",
    "sde ii": "Senior Software Engineer",
    "sde 3": "Staff Software Engineer",
    "sde iii": "Staff Software Engineer",
    "senior software engineer": "Senior Software Engineer",
    "senior developer": "Senior Software Engineer",
    "lead developer": "Lead Software Engineer",
    "tech lead": "Technical Lead",
    "technical lead": "Technical Lead",
    "principal engineer": "Principal Software Engineer",
    "staff engineer": "Staff Software Engineer",

    # Frontend
    "frontend developer": "Frontend Engineer",
    "front end developer": "Frontend Engineer",
    "frontend engineer": "Frontend Engineer",
    "front end engineer": "Frontend Engineer",
    "ui developer": "Frontend Engineer",
    "react developer": "Frontend Engineer",
    "angular developer": "Frontend Engineer",

    # Backend
    "backend developer": "Backend Engineer",
    "back end developer": "Backend Engineer",
    "backend engineer": "Backend Engineer",
    "back end engineer": "Backend Engineer",
    "api developer": "Backend Engineer",
    "python developer": "Backend Engineer",
    "java developer": "Backend Engineer",
    "golang developer": "Backend Engineer",

    # Fullstack
    "full stack developer": "Full Stack Engineer",
    "fullstack developer": "Full Stack Engineer",
    "full stack engineer": "Full Stack Engineer",
    "fullstack engineer": "Full Stack Engineer",

    # Mobile
    "mobile developer": "Mobile Engineer",
    "mobile engineer": "Mobile Engineer",
    "flutter developer": "Mobile Engineer",
    "flutter engineer": "Mobile Engineer",
    "ios developer": "iOS Engineer",
    "ios engineer": "iOS Engineer",
    "android developer": "Android Engineer",
    "android engineer": "Android Engineer",

    # Cloud & DevOps
    "devops engineer": "DevOps Engineer",
    "devops": "DevOps Engineer",
    "site reliability engineer": "Site Reliability Engineer",
    "sre": "Site Reliability Engineer",
    "cloud engineer": "Cloud Engineer",
    "cloud architect": "Cloud Architect",
    "infrastructure engineer": "Infrastructure Engineer",

    # Data & AI
    "data scientist": "Data Scientist",
    "data analyst": "Data Analyst",
    "data engineer": "Data Engineer",
    "machine learning engineer": "Machine Learning Engineer",
    "ml engineer": "Machine Learning Engineer",
    "ai engineer": "AI Engineer",
    "business intelligence analyst": "BI Analyst",
    "bi analyst": "BI Analyst",

    # Product & Design
    "product manager": "Product Manager",
    "associate product manager": "Associate Product Manager",
    "senior product manager": "Senior Product Manager",
    "product owner": "Product Owner",
    "ui/ux designer": "Product Designer",
    "ux designer": "Product Designer",
    "ui designer": "Product Designer",
    "product designer": "Product Designer",

    # QA & Testing
    "qa engineer": "QA Engineer",
    "quality assurance engineer": "QA Engineer",
    "test engineer": "QA Engineer",
    "sdet": "SDET",
    "software development engineer in test": "SDET",

    # Internships
    "software engineering intern": "Software Development Intern",
    "software developer intern": "Software Development Intern",
    "sde intern": "Software Development Intern",
    "frontend intern": "Frontend Intern",
    "backend intern": "Backend Intern",
    "data science intern": "Data Science Intern",
    "product intern": "Product Management Intern",
}


def normalize_job_title(raw_title: str) -> str:
    """Returns the canonical taxonomy role for a given job title string while preserving the original when not mapped."""
    clean = re.sub(r"[^a-zA-Z0-9\s/+#]", "", raw_title.lower())
    clean = re.sub(r"\s+", " ", clean).strip()

    if clean in _TITLE_TAXONOMY:
        return _TITLE_TAXONOMY[clean]

    # Partial / substring heuristics (match longest, most specific titles first)
    for key, canonical in sorted(_TITLE_TAXONOMY.items(), key=lambda item: len(item[0]), reverse=True):
        if re.search(r"\b" + re.escape(key) + r"\b", clean) or key in clean:
            return canonical

    return raw_title.strip()
