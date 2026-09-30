from __future__ import annotations

import httpx

from .base_provider import ResumeParserProvider
from .classifier import FileClassifier, LayoutClassification
from .models import CandidateData
from .providers.affinda import AffindaParserProvider
from .providers.local_pipeline import LocalPipelineProvider
from .providers.ocr_llm_fallback import OcrLlmFallbackProvider
from .providers.rchilli import RChilliParserProvider
from ..groq import GroqProxy


class ResumeParsingPipeline:
    """Multi-stage resume parsing pipeline: Classification -> Primary Provider -> Fallback Provider."""

    def __init__(
        self,
        client: httpx.AsyncClient,
        ai: GroqProxy | None = None,
        custom_providers: list[ResumeParserProvider] | None = None,
    ) -> None:
        self._classifier = FileClassifier()
        self._providers: list[ResumeParserProvider] = custom_providers or [
            AffindaParserProvider(client),
            RChilliParserProvider(client),
            LocalPipelineProvider(),
        ]
        self._fallback = OcrLlmFallbackProvider(ai)

    async def parse(self, bytes_data: bytes, filename: str) -> CandidateData:
        # Stage 1: File Detection & Layout Analysis
        layout: LayoutClassification = self._classifier.classify(bytes_data, filename)

        # Stage 2: Attempt Primary Resume Parsers
        for provider in self._providers:
            if not provider.is_configured:
                continue
            try:
                result = await provider.parse_resume(bytes_data, filename, layout)
                if result and result.overall_confidence >= 0.65:
                    return result
            except Exception:
                continue

        # Stage 3: Fallback Parsing Pipeline (OCR + LLM)
        try:
            fallback_result = await self._fallback.parse_resume(bytes_data, filename, layout)
            if fallback_result:
                return fallback_result
        except Exception:
            pass

        # Final safety net: local structural parser
        local_parser = LocalPipelineProvider()
        fallback_local = await local_parser.parse_resume(bytes_data, filename, layout)
        if fallback_local:
            return fallback_local

        raise ValueError(f"Could not parse document '{filename}' with any configured provider.")
