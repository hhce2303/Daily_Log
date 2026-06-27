"""Inventory serializers — zero logic, only data shape."""

from __future__ import annotations

from rest_framework import serializers

from apps.inventory.models import ActivityLog, Article, Group


# ---------------------------------------------------------------------------
# Groups
# ---------------------------------------------------------------------------

class GroupSerializer(serializers.ModelSerializer):
    # Frontend expects camelCase keys
    iconName = serializers.CharField(source="icon_name")

    class Meta:
        model = Group
        fields = ("id", "name", "description", "iconName", "color")


# ---------------------------------------------------------------------------
# Articles
# ---------------------------------------------------------------------------

class ArticleReadSerializer(serializers.ModelSerializer):
    groupId = serializers.CharField(source="group_id", allow_null=True)
    acquisitionDate = serializers.DateField(source="acquisition_date", allow_null=True)
    installStartTime = serializers.DateTimeField(source="install_start_time", allow_null=True)
    installEndTime = serializers.DateTimeField(source="install_end_time", allow_null=True)
    installDurationSeconds = serializers.IntegerField(source="install_duration_seconds", allow_null=True)
    installationLog = serializers.JSONField(source="installation_log", allow_null=True)
    modifiedBy = serializers.CharField(source="modified_by")
    latestNote = serializers.CharField(source="latest_note")
    lastMod = serializers.DateTimeField(source="updated_at", format="%Y-%m-%dT%H:%M:%S")

    class Meta:
        model = Article
        fields = (
            "id",
            "sku",
            "name",
            "sub",
            "category",
            "groupId",
            "status",
            "location",
            "acquisitionDate",
            "image",
            "serial",
            "installStartTime",
            "installEndTime",
            "installDurationSeconds",
            "installationLog",
            "modifiedBy",
            "latestNote",
            "lastMod",
        )


class ArticleWriteSerializer(serializers.Serializer):
    sku = serializers.CharField(max_length=100)
    name = serializers.CharField(max_length=200)
    sub = serializers.CharField(required=False, allow_blank=True, default="")
    category = serializers.CharField(max_length=50)
    group_id = serializers.IntegerField(required=False, allow_null=True, default=None)
    status = serializers.CharField(max_length=20, default="activo")
    location = serializers.CharField(required=False, allow_blank=True, default="")
    acquisition_date = serializers.DateField(required=False, allow_null=True, default=None)
    image = serializers.CharField(required=False, allow_blank=True, default="")
    serial = serializers.CharField(required=False, allow_blank=True, default="")
    install_start_time = serializers.DateTimeField(required=False, allow_null=True, default=None)
    install_end_time = serializers.DateTimeField(required=False, allow_null=True, default=None)
    install_duration_seconds = serializers.IntegerField(required=False, allow_null=True, default=None)
    installation_log = serializers.JSONField(required=False, allow_null=True, default=list)
    modified_by = serializers.CharField(required=False, allow_blank=True, default="")
    latest_note = serializers.CharField(required=False, allow_blank=True, default="")


class ArticleUpdateSerializer(serializers.Serializer):
    sku = serializers.CharField(max_length=100, required=False)
    name = serializers.CharField(max_length=200, required=False)
    sub = serializers.CharField(required=False, allow_blank=True)
    category = serializers.CharField(max_length=50, required=False)
    group_id = serializers.IntegerField(required=False, allow_null=True)
    status = serializers.CharField(max_length=20, required=False)
    location = serializers.CharField(required=False, allow_blank=True)
    acquisition_date = serializers.DateField(required=False, allow_null=True)
    image = serializers.CharField(required=False, allow_blank=True)
    serial = serializers.CharField(required=False, allow_blank=True)
    install_start_time = serializers.DateTimeField(required=False, allow_null=True)
    install_end_time = serializers.DateTimeField(required=False, allow_null=True)
    install_duration_seconds = serializers.IntegerField(required=False, allow_null=True)
    installation_log = serializers.JSONField(required=False, allow_null=True)
    modified_by = serializers.CharField(required=False, allow_blank=True)
    latest_note = serializers.CharField(required=False, allow_blank=True)


class FinishInstallationSerializer(serializers.Serializer):
    start_time = serializers.DateTimeField()
    end_time = serializers.DateTimeField()
    duration_seconds = serializers.IntegerField(min_value=0)
    installation_log = serializers.JSONField(required=False, default=list)
    status = serializers.ChoiceField(
        choices=("activo", "instalado"),
        default="activo",
    )


# ---------------------------------------------------------------------------
# Activity logs
# ---------------------------------------------------------------------------

class ActivityLogReadSerializer(serializers.ModelSerializer):
    articleId = serializers.IntegerField(source="article_id")
    userId = serializers.CharField(source="user_id")

    class Meta:
        model = ActivityLog
        fields = ("id", "articleId", "action", "userId", "timestamp", "notes")


class ActivityLogWriteSerializer(serializers.Serializer):
    article_id = serializers.IntegerField()
    action = serializers.CharField(max_length=100)
    user_id = serializers.CharField(max_length=100)
    notes = serializers.CharField(required=False, allow_blank=True, default="")


# ---------------------------------------------------------------------------
# Dashboard stats
# ---------------------------------------------------------------------------

class DashboardStatsSerializer(serializers.Serializer):
    enAlerta = serializers.IntegerField()
    enMantenimiento = serializers.IntegerField()
    optimo = serializers.IntegerField()
    total = serializers.IntegerField()
