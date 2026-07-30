"""Structured logging.

We log security-relevant events (auth, consent, deletion, access denials) as
structured records. IMPORTANT: never log raw scan bytes, signed URLs, tokens,
or full email addresses. Helpers here scrub obvious secrets.
"""

from __future__ import annotations

import logging
import sys

import structlog


def configure_logging(level: str = "INFO") -> None:
    logging.basicConfig(format="%(message)s", stream=sys.stdout, level=level.upper())
    structlog.configure(
        processors=[
            structlog.contextvars.merge_contextvars,
            structlog.processors.add_log_level,
            structlog.processors.TimeStamper(fmt="iso"),
            structlog.processors.StackInfoRenderer(),
            structlog.processors.format_exc_info,
            structlog.processors.JSONRenderer(),
        ],
        wrapper_class=structlog.make_filtering_bound_logger(
            logging.getLevelName(level.upper())
        ),
        logger_factory=structlog.PrintLoggerFactory(),
        cache_logger_on_first_use=True,
    )


def get_logger(name: str = "wardrobe") -> structlog.stdlib.BoundLogger:
    return structlog.get_logger(name)


def mask_email(email: str) -> str:
    """Return a privacy-preserving representation of an email for logs."""
    if "@" not in email:
        return "***"
    local, _, domain = email.partition("@")
    shown = local[0] if local else "*"
    return f"{shown}***@{domain}"
