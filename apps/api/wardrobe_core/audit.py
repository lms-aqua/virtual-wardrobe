"""Audit logging helper. Writes a durable audit_events row + a structured log.

Never pass raw scan bytes, tokens, signed URLs, or full emails in ``meta``.
"""

from __future__ import annotations

import uuid

from sqlalchemy.ext.asyncio import AsyncSession

from wardrobe_core.logging import get_logger
from wardrobe_core.models import AuditEvent

log = get_logger("audit")


async def record(
    session: AsyncSession,
    *,
    action: str,
    actor_user_id: uuid.UUID | None = None,
    target_type: str | None = None,
    target_id: str | None = None,
    ip: str | None = None,
    meta: dict | None = None,
) -> None:
    session.add(
        AuditEvent(
            actor_user_id=actor_user_id,
            action=action,
            target_type=target_type,
            target_id=target_id,
            ip=ip,
            meta=meta,
        )
    )
    log.info(
        "audit",
        action=action,
        actor=str(actor_user_id) if actor_user_id else None,
        target_type=target_type,
        target_id=target_id,
    )
