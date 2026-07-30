"""Dramatiq worker entrypoint.

The broker is defined here; Phase 4 registers the scan-validation, avatar-fit,
mesh-optimize, thumbnail, and garment-fit actors. All CV steps are dispatched
through swappable provider interfaces (see wardrobe_core.providers, added later).
"""

from __future__ import annotations

import dramatiq
from dramatiq.brokers.redis import RedisBroker

from wardrobe_core.config import get_settings
from wardrobe_core.logging import configure_logging, get_logger

settings = get_settings()
configure_logging(settings.log_level)
log = get_logger("worker")

broker = RedisBroker(url=settings.effective_redis_url)
dramatiq.set_broker(broker)


@dramatiq.actor(max_retries=3)
def ping() -> None:
    """Trivial actor proving the broker round-trips."""
    log.info("worker.ping")


@dramatiq.actor(max_retries=3, time_limit=600_000)
def process_scan_actor(scan_id: str) -> None:
    """Run the scan → avatar pipeline in the background worker."""
    import asyncio
    import uuid

    from wardrobe_core.services.processing import process_scan

    asyncio.run(process_scan(uuid.UUID(scan_id)))
