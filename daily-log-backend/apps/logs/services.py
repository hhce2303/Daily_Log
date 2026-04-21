"""
Write operations for daily events.

Services handle business logic and mutations — views never touch the ORM directly.
"""

from __future__ import annotations

from typing import Any

from django.utils import timezone

from apps.core.exceptions import ResourceNotFound
from apps.core.models import Activity, Site, User as DailyUser
from apps.logs.models import DailyEvent
from apps.logs.selectors import is_special_site


def create_event(
    daily_user: DailyUser,
    *,
    site_id: int,
    activity_id: int,
    quantity: int,
    camera: str | None = None,
    description: str | None = None,
) -> DailyEvent:
    """
    Create a new daily event.

    - User resolved from JWT (passed in).
    - event_datetime set server-side (now).
    - event_status: if the site belongs to a special group → 'pending',
      otherwise → 'confirmed'.
    """
    # Validate FK existence
    if not Site.objects.filter(pk=site_id).exists():
        raise ResourceNotFound(f"Sitio {site_id} no encontrado.")

    if not Activity.objects.filter(pk=activity_id).exists():
        raise ResourceNotFound(f"Actividad {activity_id} no encontrada.")

    # Detect if the site is special
    is_special = is_special_site(site_id)
    event_status = "draft" if is_special else "confirmed"

    event = DailyEvent.objects.create(
        user_id=daily_user.pk,
        site_id=site_id,
        activity_id=activity_id,
        event_datetime=timezone.now(),
        event_status=event_status,
        quantity=str(quantity),
        camera=camera or "",
        description=description or "",
    )

    # Reload with relations for the response serializer
    return (
        DailyEvent.objects
        .select_related("site", "activity")
        .get(pk=event.pk)
    )
