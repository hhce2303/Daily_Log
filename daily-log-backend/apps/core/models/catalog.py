from django.db import models


class Site(models.Model):
    id = models.AutoField(primary_key=True, db_column="ID_site")
    group_id = models.CharField(max_length=45, db_column="ID_group")
    site_name = models.CharField(max_length=200, db_column="site_name")
    site_dns = models.CharField(max_length=200, null=True, blank=True, db_column="site_dns")
    site_timezone = models.CharField(max_length=50, null=True, blank=True, db_column="site_timezone")

    class Meta:
        managed = False
        db_table = "daily_sites"

    def __str__(self) -> str:
        return self.site_name


class Activity(models.Model):
    id = models.AutoField(primary_key=True, db_column="ID_activity")
    act_name = models.CharField(max_length=200, db_column="act_name")

    class Meta:
        managed = False
        db_table = "daily_activities"

    def __str__(self) -> str:
        return self.act_name


class SpecialGroup(models.Model):
    id = models.AutoField(primary_key=True, db_column="ID_site_special")
    group_code = models.CharField(max_length=5, db_column="site_group_special")

    class Meta:
        managed = False
        db_table = "daily_special_groups"

    def __str__(self) -> str:
        return self.group_code
