"""
Read-only queries for notifications (specials).

All DB filtering happens here — never in views or services.
The Q(spec_status__isnull=True) guard is intentional: MySQL treats
  NOT (NULL = 'done')  as NULL (falsy), so a plain .exclude() would
  silently drop rows where spec_status IS NULL.

Timezone offset resolution (season-aware):
  US sites observe DST, so the offset from Colombia time differs between
  Winter and Summer. The active season is stored in ``daily_season_offsets``
  (active=1). Depending on the season, the offset is read from either
  ``daily_winter_offsets`` or ``daily_summer_offsets``.

  Lookup chain:
    site.site_timezone  →  active season  →  correct offsets table  →  offset
"""

from __future__ import annotations

from django.db.models import Q, QuerySet

from apps.core.models import SeasonConfig, SummerOffset, WinterOffset
from apps.notifications.models import Special


def get_supervisor_pending_specials(supervisor_id: int) -> QuerySet[Special]:
    """
    Return specials assigned to *supervisor_id* that are not 'done'.

    Equivalent to the legacy:
        load_specials_by_supervisor(id_supervisor, status_filter='done')

    One query with 3 JOINs via select_related — no N+1.
    """
    return (
        Special.objects
        .filter(supervisor_id=supervisor_id)
        .filter(Q(spec_status__isnull=True) | ~Q(spec_status="done"))
        .select_related("site", "activity", "user__profile")
        .order_by("-spec_datetime")
    )


def get_timezone_offset_for_site(site_timezone: str | None) -> float:
    """
    Return the numeric hour offset for *site_timezone* using the active season.

    Steps:
      1. Query ``daily_season_offsets`` for the row with active=1.
      2. Determine the offsets table: winter → ``daily_winter_offsets``,
         summer → ``daily_summer_offsets``.
      3. Look up ``time_offset`` where ``time_zone = site_timezone``.

    Returns 0.0 in any of these fallback cases (no crash, no wrong data):
      - site_timezone is None / empty
      - no active season configured
      - unknown season value
      - timezone not found in the season table
    """
    if not site_timezone:
        return 0.0

    # Step 1: get the active season name ('winter' | 'summer')
    active_season = (
        SeasonConfig.objects
        .filter(active=1)
        .values_list("season_offsets", flat=True)
        .first()
    )
    if not active_season:
        return 0.0

    # Step 2: choose the correct offsets model
    season = active_season.lower()
    if season == "winter":
        offset_model = WinterOffset
    elif season == "summer":
        offset_model = SummerOffset
    else:
        return 0.0

    # Step 3: look up the offset for this specific timezone
    result = (
        offset_model.objects
        .filter(time_zone=site_timezone)
        .values_list("time_offset", flat=True)
        .first()
    )

    return float(result) if result is not None else 0.0
