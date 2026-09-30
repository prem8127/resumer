from __future__ import annotations

from dataclasses import dataclass
from enum import StrEnum
import re


class DocumentFormat(StrEnum):
    PDF = "pdf"
    DOCX = "docx"
    DOC = "doc"
    TXT = "txt"
    RTF = "rtf"
    IMAGE = "image"
    UNKNOWN = "unknown"


@dataclass(frozen=True, slots=True)
class LayoutClassification:
    format: DocumentFormat
    is_scanned: bool
    has_multiple_columns: bool
    has_tables: bool
    estimated_page_count: int
    confidence: float
    description: str


class FileClassifier:
    """Classifies document file types and detects layout characteristics (multi-column, tables, scanned)."""

    def classify(self, bytes_data: bytes, filename: str) -> LayoutClassification:
        fmt = self._detect_format(bytes_data, filename)
        is_scanned = False
        has_multi_col = False
        has_tables = False
        pages = 1

        if fmt == DocumentFormat.PDF:
            is_scanned, has_multi_col, has_tables, pages = self._analyze_pdf(bytes_data)
        elif fmt == DocumentFormat.IMAGE:
            is_scanned = True
        elif fmt in {DocumentFormat.DOCX, DocumentFormat.DOC}:
            has_tables = b"w:tbl" in bytes_data or b"\\trowd" in bytes_data
            has_multi_col = b"w:cols" in bytes_data
        elif fmt == DocumentFormat.TXT:
            has_multi_col = False
            has_tables = False

        desc_parts = [fmt.value.upper()]
        if is_scanned:
            desc_parts.append("scanned/raster layout")
        if has_multi_col:
            desc_parts.append("multi-column layout")
        if has_tables:
            desc_parts.append("tabular structures")

        return LayoutClassification(
            format=fmt,
            is_scanned=is_scanned,
            has_multiple_columns=has_multi_col,
            has_tables=has_tables,
            estimated_page_count=pages,
            confidence=0.95 if fmt != DocumentFormat.UNKNOWN else 0.4,
            description=", ".join(desc_parts),
        )

    def _detect_format(self, data: bytes, filename: str) -> DocumentFormat:
        ext = filename.split(".")[-1].lower() if "." in filename else ""

        # Check magic bytes first
        if data.startswith(b"%PDF"):
            return DocumentFormat.PDF
        if data.startswith(b"PK\x03\x04"):
            # Check for docx inside ZIP
            if b"word/" in data[:2000]:
                return DocumentFormat.DOCX
            return DocumentFormat.DOCX
        if data.startswith(b"\xd0\xcf\x11\xe0\xa1\xb1\x1a\xe1"):
            return DocumentFormat.DOC
        if data.startswith(b"{\\rtf"):
            return DocumentFormat.RTF
        if data.startswith(b"\x89PNG\r\n\x1a\n") or data.startswith(b"\xff\xd8\xff"):
            return DocumentFormat.IMAGE

        # Fallback to extension
        ext_map = {
            "pdf": DocumentFormat.PDF,
            "docx": DocumentFormat.DOCX,
            "doc": DocumentFormat.DOC,
            "rtf": DocumentFormat.RTF,
            "txt": DocumentFormat.TXT,
            "md": DocumentFormat.TXT,
            "png": DocumentFormat.IMAGE,
            "jpg": DocumentFormat.IMAGE,
            "jpeg": DocumentFormat.IMAGE,
            "webp": DocumentFormat.IMAGE,
        }
        return ext_map.get(ext, DocumentFormat.UNKNOWN)

    def _analyze_pdf(self, data: bytes) -> tuple[bool, bool, bool, int]:
        # Count page markers in PDF
        page_matches = len(re.findall(rb"/Type\s*/Page\b", data))
        pages = max(1, page_matches)

        # Scanned check: if PDF has /Image objects but almost zero text streams
        stream_matches = len(re.findall(rb"stream[\r\n]", data))
        font_matches = len(re.findall(rb"/Type\s*/Font\b", data))
        image_matches = len(re.findall(rb"/Subtype\s*/Image\b", data))

        is_scanned = (font_matches == 0 and image_matches > 0) or (len(data) > 20000 and font_matches == 0)

        # Multi-column heuristic: column / layout operators or dual margins
        has_multi_col = b"/Columns" in data or b"/Col" in data

        # Table markers
        has_tables = b"/Table" in data or b"/TR" in data or b"/TD" in data

        return is_scanned, has_multi_col, has_tables, pages
