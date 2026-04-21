"""
Read-only, unmanaged models that map to the sigtools_beta database.
Django never creates or migrates these tables.
"""

from django.db import models


class Site(models.Model):
    id = models.BigAutoField(primary_key=True)
    name = models.CharField(max_length=255)
    deleted_at = models.DateTimeField(null=True, blank=True, db_column="deleted_at")

    class Meta:
        app_label = "sigtools"
        managed = False
        db_table = "sites"
