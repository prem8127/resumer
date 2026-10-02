from __future__ import annotations

from dataclasses import dataclass
import os
from pathlib import Path

from dotenv import load_dotenv


load_dotenv(Path(__file__).resolve().parents[1] / ".env")

DEFAULT_GROQ_API_KEY = ""
PRODUCTION_WEB_ORIGINS = (
    "https://web-seven-lovat-95.vercel.app",
    "https://web-premsagars-projects-fa9ef47b.vercel.app",
)


@dataclass(frozen=True, slots=True)
class Settings:
    groq_api_key: str
    groq_model: str
    api_key: str
    cors_origins: tuple[str, ...]
    cors_origin_regex: str | None
    request_timeout_seconds: float
    max_concurrency: int
    supabase_url: str = ""
    supabase_publishable_key: str = ""
    supabase_service_role_key: str = ""
    rapidapi_key: str = ""
    vibevoice_asr_url: str = ""
    vibevoice_asr_api_key: str = ""
    vibevoice_asr_timeout_seconds: float = 240.0

    @classmethod
    def from_environment(cls) -> "Settings":
        configured_origins = tuple(
            origin.strip()
            for origin in os.getenv(
                "RESUMER_CORS_ORIGINS",
                "http://localhost:8080,http://127.0.0.1:8080",
            ).split(",")
            if origin.strip()
        )
        origins = tuple(dict.fromkeys((*configured_origins, *PRODUCTION_WEB_ORIGINS)))
        return cls(
            groq_api_key=os.getenv("GROQ_API_KEY", DEFAULT_GROQ_API_KEY).strip()
            or DEFAULT_GROQ_API_KEY,
            groq_model=os.getenv("GROQ_MODEL", "openai/gpt-oss-20b").strip(),
            api_key=os.getenv("RESUMER_API_KEY", "").strip(),
            cors_origins=origins,
            cors_origin_regex=os.getenv(
                "RESUMER_CORS_ORIGIN_REGEX",
                r"^https?://(localhost|127\.0\.0\.1)(:\d+)?$",
            ).strip()
            or None,
            request_timeout_seconds=float(
                os.getenv("RESUMER_SCRAPE_TIMEOUT_SECONDS", "12")
            ),
            max_concurrency=max(
                1, int(os.getenv("RESUMER_SCRAPE_MAX_CONCURRENCY", "6"))
            ),
            supabase_url=os.getenv("SUPABASE_URL", "").strip().rstrip("/"),
            supabase_publishable_key=os.getenv("SUPABASE_PUBLISHABLE_KEY", "").strip(),
            supabase_service_role_key=os.getenv("SUPABASE_SERVICE_ROLE_KEY", "").strip(),
            rapidapi_key=os.getenv("RAPIDAPI_KEY", "").strip(),
            vibevoice_asr_url=os.getenv("VIBEVOICE_ASR_URL", "").strip().rstrip("/"),
            vibevoice_asr_api_key=os.getenv("VIBEVOICE_ASR_API_KEY", "").strip(),
            vibevoice_asr_timeout_seconds=float(
                os.getenv("VIBEVOICE_ASR_TIMEOUT_SECONDS", "240")
            ),
        )
