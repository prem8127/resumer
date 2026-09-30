from __future__ import annotations

from abc import ABC, abstractmethod

from .classifier import LayoutClassification
from .models import CandidateData


class ResumeParserProvider(ABC):
    """Common interface for external (Affinda, RChilli) and local resume parsers."""

    @property
    @abstractmethod
    def provider_name(self) -> str:
        """Identifier for this provider, e.g. 'affinda', 'rchilli', 'local'."""
        ...

    @property
    @abstractmethod
    def is_configured(self) -> bool:
        """True if the provider has necessary API keys / self-hosted endpoints configured."""
        ...

    @abstractmethod
    async def parse_resume(
        self,
        bytes_data: bytes,
        filename: str,
        layout: LayoutClassification,
    ) -> CandidateData | None:
        """Parses the document into normalized candidate JSON with confidence scores."""
        ...
