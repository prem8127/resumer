from __future__ import annotations

import re

# Comprehensive canonical skill mapping covering programming languages, frameworks,
# cloud platforms, databases, methodologies, and tools.
_SKILL_SYNONYMS: dict[str, str] = {
    # Languages
    "js": "JavaScript",
    "javascript": "JavaScript",
    "java script": "JavaScript",
    "ts": "TypeScript",
    "typescript": "TypeScript",
    "type script": "TypeScript",
    "py": "Python",
    "python": "Python",
    "python3": "Python",
    "golang": "Go",
    "go": "Go",
    "c++": "C++",
    "cpp": "C++",
    "c#": "C#",
    "csharp": "C#",
    "cs": "C#",
    "rb": "Ruby",
    "ruby": "Ruby",
    "rust": "Rust",
    "php": "PHP",
    "kotlin": "Kotlin",
    "swift": "Swift",
    "dart": "Dart",
    "scala": "Scala",
    "r": "R",
    "matlab": "MATLAB",
    "sql": "SQL",
    "pl/sql": "PL/SQL",
    "bash": "Bash",
    "shell": "Shell Scripting",
    "powershell": "PowerShell",

    # Frontend & Mobile
    "react": "React",
    "react.js": "React",
    "reactjs": "React",
    "react native": "React Native",
    "reactnative": "React Native",
    "flutter": "Flutter",
    "flutter sdk": "Flutter",
    "vue": "Vue.js",
    "vue.js": "Vue.js",
    "vuejs": "Vue.js",
    "angular": "Angular",
    "angular.js": "Angular",
    "angularjs": "Angular",
    "svelte": "Svelte",
    "next": "Next.js",
    "next.js": "Next.js",
    "nextjs": "Next.js",
    "nuxt": "Nuxt.js",
    "nuxt.js": "Nuxt.js",
    "html": "HTML5",
    "html5": "HTML5",
    "css": "CSS3",
    "css3": "CSS3",
    "tailwind": "Tailwind CSS",
    "tailwindcss": "Tailwind CSS",
    "sass": "Sass",
    "scss": "Sass",
    "bootstrap": "Bootstrap",

    # Backend & Frameworks
    "node": "Node.js",
    "nodejs": "Node.js",
    "node.js": "Node.js",
    "express": "Express.js",
    "expressjs": "Express.js",
    "fastapi": "FastAPI",
    "django": "Django",
    "flask": "Flask",
    "spring": "Spring Boot",
    "spring boot": "Spring Boot",
    "springboot": "Spring Boot",
    ".net": ".NET",
    "dotnet": ".NET",
    ".net core": ".NET Core",
    "asp.net": "ASP.NET",
    "rails": "Ruby on Rails",
    "ruby on rails": "Ruby on Rails",
    "graphql": "GraphQL",
    "rest": "REST APIs",
    "rest api": "REST APIs",
    "restful": "REST APIs",
    "grpc": "gRPC",

    # Databases
    "postgres": "PostgreSQL",
    "postgresql": "PostgreSQL",
    "psql": "PostgreSQL",
    "mysql": "MySQL",
    "mongo": "MongoDB",
    "mongodb": "MongoDB",
    "redis": "Redis",
    "dynamodb": "DynamoDB",
    "sqlite": "SQLite",
    "cassandra": "Cassandra",
    "elasticsearch": "Elasticsearch",
    "opensearch": "OpenSearch",
    "oracle": "Oracle Database",
    "firebase": "Firebase",
    "firestore": "Firestore",
    "supabase": "Supabase",

    # Cloud & DevOps
    "aws": "AWS",
    "amazon web services": "AWS",
    "gcp": "Google Cloud",
    "google cloud": "Google Cloud",
    "google cloud platform": "Google Cloud",
    "azure": "Microsoft Azure",
    "microsoft azure": "Microsoft Azure",
    "k8s": "Kubernetes",
    "kubernetes": "Kubernetes",
    "docker": "Docker",
    "docker compose": "Docker Compose",
    "terraform": "Terraform",
    "ansible": "Ansible",
    "ci/cd": "CI/CD",
    "cicd": "CI/CD",
    "jenkins": "Jenkins",
    "github actions": "GitHub Actions",
    "gitlab ci": "GitLab CI",

    # Architecture & Concepts
    "microservices": "Microservices",
    "distributed systems": "Distributed Systems",
    "system design": "System Design",
    "oop": "Object-Oriented Programming",
    "tdd": "Test-Driven Development",
    "agile": "Agile / Scrum",
    "scrum": "Agile / Scrum",

    # Data & AI
    "ml": "Machine Learning",
    "machine learning": "Machine Learning",
    "ai": "Artificial Intelligence",
    "deep learning": "Deep Learning",
    "nlp": "Natural Language Processing",
    "computer vision": "Computer Vision",
    "pandas": "Pandas",
    "numpy": "NumPy",
    "pytorch": "PyTorch",
    "tensorflow": "TensorFlow",
    "scikit-learn": "Scikit-Learn",
    "llm": "LLMs",
    "langchain": "LangChain",
    "genai": "Generative AI",
}


def normalize_skill(skill_name: str) -> str:
    """Normalizes skill aliases to canonical form, or cleans the raw string."""
    cleaned = re.sub(r"\s+", " ", skill_name.strip().lower())
    if cleaned in _SKILL_SYNONYMS:
        return _SKILL_SYNONYMS[cleaned]
    # Capitalize appropriately if no direct alias
    return skill_name.strip()


def normalize_skills(skills: list[str]) -> list[str]:
    """Normalizes a list of skills and removes duplicates while preserving order."""
    seen: set[str] = set()
    result: list[str] = []
    for skill in skills:
        if not skill or not skill.strip():
            continue
        canonical = normalize_skill(skill)
        canonical_key = canonical.lower()
        if canonical_key not in seen:
            seen.add(canonical_key)
            result.append(canonical)
    return result
