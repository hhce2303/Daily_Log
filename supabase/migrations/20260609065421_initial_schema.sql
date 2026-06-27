-- ============================================================
-- Dump: sig_dailylogs
-- Host: 72.167.56.142:3306
-- Fecha: 2026-05-12 01:56:12
-- Generado por: scripts/dump_database.py
-- ============================================================

-- SET NAMES utf8mb4;
-- SET character_set_client = utf8mb4;
-- SET FOREIGN_KEY_CHECKS = 0;
-- SET SQL_MODE = 'NO_AUTO_VALUE_ON_ZERO';

-- Crea la base de datos destino (cámbiala si ya existe con otro nombre)
-- CREATE DATABASE IF NOT EXISTS `sig_dailylogs_clone`
--  DEFAULT CHARACTER SET utf8mb4
--  DEFAULT COLLATE utf8mb4_unicode_ci;

-- USE `sig_dailylogs_clone`;

-- ----------------------------------------------------------
-- Tabla: auth_group
-- ----------------------------------------------------------
DROP TABLE IF EXISTS "auth_group";
CREATE TABLE "auth_group" (
  "id" INTEGER NOT NULL,
  "name" VARCHAR NOT NULL,
  PRIMARY KEY ("id")-- UNIQUE KEY "name" ("name")
);

-- (sin registros)

-- ----------------------------------------------------------
-- Tabla: auth_group_permissions
-- ----------------------------------------------------------
DROP TABLE IF EXISTS "auth_group_permissions";
CREATE TABLE "auth_group_permissions" (
  "id" BIGINT NOT NULL,
  "group_id" INTEGER NOT NULL,
  "permission_id" INTEGER NOT NULL,
  PRIMARY KEY ("id")-- UNIQUE KEY "auth_group_permissions_group_id_permission_id_0cd325b0_uniq" ("group_id","permission_id"),
-- KEY "auth_group_permissio_permission_id_84c5c92e_fk_auth_perm" ("permission_id"),
-- CONSTRAINT "auth_group_permissio_permission_id_84c5c92e_fk_auth_perm" FOREIGN KEY ("permission_id") REFERENCES "auth_permission" ("id"),
-- CONSTRAINT "auth_group_permissions_group_id_b120cbf9_fk_auth_group_id" FOREIGN KEY ("group_id") REFERENCES "auth_group" ("id")
);

-- (sin registros)

-- ----------------------------------------------------------
-- Tabla: auth_permission
-- ----------------------------------------------------------
DROP TABLE IF EXISTS "auth_permission";
CREATE TABLE "auth_permission" (
  "id" INTEGER NOT NULL,
  "name" VARCHAR NOT NULL,
  "content_type_id" INTEGER NOT NULL,
  "codename" VARCHAR NOT NULL,
  PRIMARY KEY ("id")-- UNIQUE KEY "auth_permission_content_type_id_codename_01ab375a_uniq" ("content_type_id","codename"),
-- CONSTRAINT "auth_permission_content_type_id_2f476e4b_fk_django_co" FOREIGN KEY ("content_type_id") REFERENCES "django_content_type" ("id")
);


-- ----------------------------------------------------------
-- Tabla: auth_user
-- ----------------------------------------------------------
DROP TABLE IF EXISTS "auth_user";
CREATE TABLE "auth_user" (
  "id" INTEGER NOT NULL,
  "password" VARCHAR NOT NULL,
  "last_login" TIMESTAMP DEFAULT NULL,
  "is_superuser" SMALLINT NOT NULL,
  "username" VARCHAR NOT NULL,
  "first_name" VARCHAR NOT NULL,
  "last_name" VARCHAR NOT NULL,
  "email" VARCHAR NOT NULL,
  "is_staff" SMALLINT NOT NULL,
  "is_active" SMALLINT NOT NULL,
  "date_joined" TIMESTAMP NOT NULL,
  PRIMARY KEY ("id")-- UNIQUE KEY "username" ("username")
);


-- ----------------------------------------------------------
-- Tabla: auth_user_groups
-- ----------------------------------------------------------
DROP TABLE IF EXISTS "auth_user_groups";
CREATE TABLE "auth_user_groups" (
  "id" BIGINT NOT NULL,
  "user_id" INTEGER NOT NULL,
  "group_id" INTEGER NOT NULL,
  PRIMARY KEY ("id")-- UNIQUE KEY "auth_user_groups_user_id_group_id_94350c0c_uniq" ("user_id","group_id"),
-- KEY "auth_user_groups_group_id_97559544_fk_auth_group_id" ("group_id"),
-- CONSTRAINT "auth_user_groups_group_id_97559544_fk_auth_group_id" FOREIGN KEY ("group_id") REFERENCES "auth_group" ("id"),
-- CONSTRAINT "auth_user_groups_user_id_6a12ed8b_fk_auth_user_id" FOREIGN KEY ("user_id") REFERENCES "auth_user" ("id")
);

-- (sin registros)

-- ----------------------------------------------------------
-- Tabla: auth_user_user_permissions
-- ----------------------------------------------------------
DROP TABLE IF EXISTS "auth_user_user_permissions";
CREATE TABLE "auth_user_user_permissions" (
  "id" BIGINT NOT NULL,
  "user_id" INTEGER NOT NULL,
  "permission_id" INTEGER NOT NULL,
  PRIMARY KEY ("id")-- UNIQUE KEY "auth_user_user_permissions_user_id_permission_id_14a6b632_uniq" ("user_id","permission_id"),
-- KEY "auth_user_user_permi_permission_id_1fbb5f2c_fk_auth_perm" ("permission_id"),
-- CONSTRAINT "auth_user_user_permi_permission_id_1fbb5f2c_fk_auth_perm" FOREIGN KEY ("permission_id") REFERENCES "auth_permission" ("id"),
-- CONSTRAINT "auth_user_user_permissions_user_id_a95ead1b_fk_auth_user_id" FOREIGN KEY ("user_id") REFERENCES "auth_user" ("id")
);


-- ----------------------------------------------------------
-- Tabla: daily_activities
-- ----------------------------------------------------------
DROP TABLE IF EXISTS "daily_activities";
CREATE TABLE "daily_activities" (
  "ID_Activity" INTEGER NOT NULL,
  "act_name" VARCHAR NOT NULL,
  PRIMARY KEY ("ID_Activity")
);


-- ----------------------------------------------------------
-- Tabla: daily_audit_log
-- ----------------------------------------------------------
DROP TABLE IF EXISTS "daily_audit_log";
CREATE TABLE "daily_audit_log" (
  "id" BIGINT NOT NULL,
  "user_id" INTEGER NOT NULL,
  "session_id" INTEGER DEFAULT NULL,
  "action" VARCHAR NOT NULL,
  "resource" VARCHAR NOT NULL,
  "resource_id" INTEGER DEFAULT NULL,
  "detail" TEXT   DEFAULT NULL ,
  "ip_address" char(39) DEFAULT NULL,
  "user_agent" VARCHAR DEFAULT NULL,
  "created_at" TIMESTAMP NOT NULL,
  PRIMARY KEY ("id")-- KEY "daily_audit_log_user_id_0f7474e8" ("user_id"),
-- KEY "daily_audit_user_id_0c6dc6_idx" ("user_id","created_at"),
-- KEY "daily_audit_action_652670_idx" ("action","created_at"),
-- KEY "daily_audit_created_88ce71_idx" ("created_at")
);

-- (sin registros)

-- ----------------------------------------------------------
-- Tabla: daily_breaks
-- ----------------------------------------------------------
DROP TABLE IF EXISTS "daily_breaks";
CREATE TABLE "daily_breaks" (
  "ID_break" INTEGER NOT NULL,
  "ID_user_covering" INTEGER NOT NULL,
  "ID_user_covered" INTEGER NOT NULL,
  "break_datetime" TIMESTAMP NOT NULL,
  "active" SMALLINT NOT NULL,
  "ID_supervisor" INTEGER NOT NULL,
  "break_creation" TIMESTAMP NOT NULL,
  PRIMARY KEY ("ID_break")-- KEY "break_id_user_idx" ("ID_user_covering"),
-- KEY "break_id_user_covered_idx" ("ID_user_covered"),
-- KEY "break_id_supervisor_idx" ("ID_supervisor"),
-- CONSTRAINT "break_id_supervisor" FOREIGN KEY ("ID_supervisor") REFERENCES "daily_users" ("ID_user"),
-- CONSTRAINT "break_id_user_covered" FOREIGN KEY ("ID_user_covered") REFERENCES "daily_users" ("ID_user"),
-- CONSTRAINT "break_id_user_covering" FOREIGN KEY ("ID_user_covering") REFERENCES "daily_users" ("ID_user")
);


-- ----------------------------------------------------------
-- Tabla: daily_covers_completed
-- ----------------------------------------------------------
DROP TABLE IF EXISTS "daily_covers_completed";
CREATE TABLE "daily_covers_completed" (
  "ID_cover_complete" INTEGER NOT NULL,
  "ID_user" INTEGER NOT NULL,
  "ID_cover_solicitude" INTEGER NOT NULL,
  "cover_in" TIMESTAMP NOT NULL,
  "cover_out" TIMESTAMP DEFAULT NULL,
  "cover_type" INTEGER NOT NULL,
  "ID_cover_by" INTEGER NOT NULL,
  PRIMARY KEY ("ID_cover_complete")-- KEY "compl_cover_id_user_idx" ("ID_user"),
-- KEY "compl_cover_id_solicitude_idx" ("ID_cover_solicitude"),
-- KEY "compl_cover_id_cover_by_idx" ("ID_cover_by"),
-- KEY "compl_cover_id_type_idx" ("cover_type"),
-- CONSTRAINT "compl_cover_id_cover_by" FOREIGN KEY ("ID_cover_by") REFERENCES "daily_users" ("ID_user"),
-- CONSTRAINT "compl_cover_id_solicitude" FOREIGN KEY ("ID_cover_solicitude") REFERENCES "daily_covers_solicitudes" ("ID_cover"),
-- CONSTRAINT "compl_cover_id_type" FOREIGN KEY ("cover_type") REFERENCES "daily_covers_types" ("ID_cover_type"),
-- CONSTRAINT "compl_cover_id_user" FOREIGN KEY ("ID_user") REFERENCES "daily_users" ("ID_user")
);






-- ----------------------------------------------------------
-- Tabla: daily_covers_solicitudes
-- ----------------------------------------------------------
DROP TABLE IF EXISTS "daily_covers_solicitudes";
CREATE TABLE "daily_covers_solicitudes" (
  "ID_cover" INTEGER NOT NULL,
  "ID_user" INTEGER NOT NULL,
  "cover_time_request" TIMESTAMP NOT NULL,
  "ID_station" INTEGER NOT NULL,
  "approved" SMALLINT NOT NULL,
  "active" SMALLINT NOT NULL,
  PRIMARY KEY ("ID_cover")-- KEY "solic_cover_id_user_idx" ("ID_user"),
-- KEY "solic_cover_id_station_idx" ("ID_station"),
-- CONSTRAINT "solic_cover_id_station" FOREIGN KEY ("ID_station") REFERENCES "daily_stations_info" ("ID_station"),
-- CONSTRAINT "solic_cover_id_user" FOREIGN KEY ("ID_user") REFERENCES "daily_users" ("ID_user")
);






-- ----------------------------------------------------------
-- Tabla: daily_covers_types
-- ----------------------------------------------------------
DROP TABLE IF EXISTS "daily_covers_types";
CREATE TABLE "daily_covers_types" (
  "ID_cover_type" INTEGER NOT NULL,
  "cover_type" VARCHAR NOT NULL,
  PRIMARY KEY ("ID_cover_type")
);


-- ----------------------------------------------------------
-- Tabla: daily_disconnected_sites
-- ----------------------------------------------------------
DROP TABLE IF EXISTS "daily_disconnected_sites";
CREATE TABLE "daily_disconnected_sites" (
  "ID_dis_site" INTEGER NOT NULL,
  "ID_station" INTEGER NOT NULL,
  "ID_user" INTEGER NOT NULL,
  "ID_site" INTEGER NOT NULL,
  "dis_datetime" TIMESTAMP NOT NULL,
  "dis_reconnect_datetime" TIMESTAMP DEFAULT NULL,
  "active" SMALLINT NOT NULL,
  "force" SMALLINT NOT NULL DEFAULT 0,
  PRIMARY KEY ("ID_dis_site")
);




-- ----------------------------------------------------------
-- Tabla: daily_events
-- ----------------------------------------------------------
DROP TABLE IF EXISTS "daily_events";
CREATE TABLE "daily_events" (
  "ID_event" INTEGER NOT NULL,
  "event_datetime" TIMESTAMP NOT NULL,
  "ID_site" INTEGER NOT NULL,
  "ID_activity" INTEGER NOT NULL,
  "event_quantity" VARCHAR DEFAULT NULL,
  "event_camera" VARCHAR DEFAULT NULL,
  "event_description" VARCHAR DEFAULT NULL,
  "ID_user" INTEGER NOT NULL,
  "event_status" VARCHAR NOT NULL DEFAULT 'confirmed',
  PRIMARY KEY ("ID_event")-- KEY "event_user_id_idx" ("ID_user"),
-- KEY "event_id_site_idx" ("ID_site"),
-- KEY "event_id_activity_idx" ("ID_activity"),
-- KEY "idx_event_status" ("event_status"),
-- CONSTRAINT "event_id_activity" FOREIGN KEY ("ID_activity") REFERENCES "daily_activities" ("ID_Activity"),
-- CONSTRAINT "event_id_site" FOREIGN KEY ("ID_site") REFERENCES "daily_sites" ("ID_site"),
-- CONSTRAINT "event_id_user" FOREIGN KEY ("ID_user") REFERENCES "daily_users" ("ID_user")
);

































-- ----------------------------------------------------------
-- Tabla: daily_events_deleted
-- ----------------------------------------------------------
DROP TABLE IF EXISTS "daily_events_deleted";
CREATE TABLE "daily_events_deleted" (
  "ID_event" INTEGER NOT NULL,
  "event_datetime" TIMESTAMP NOT NULL,
  "ID_site" INTEGER NOT NULL,
  "ID_activity" INTEGER NOT NULL,
  "event_quantity" VARCHAR DEFAULT NULL,
  "event_camera" VARCHAR DEFAULT NULL,
  "event_description" VARCHAR DEFAULT NULL,
  "ID_user" INTEGER NOT NULL,
  "deleted_at" timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_by" VARCHAR DEFAULT NULL,
  "deletion_reason" text DEFAULT NULL,
  PRIMARY KEY ("ID_event")
);


-- ----------------------------------------------------------
-- Tabla: daily_hc_sites
-- ----------------------------------------------------------
DROP TABLE IF EXISTS "daily_hc_sites";
CREATE TABLE "daily_hc_sites" (
  "ID_sitio" INTEGER NOT NULL,
  "cameras_totales" VARCHAR NOT NULL DEFAULT '0',
  "cameras_down" VARCHAR NOT NULL DEFAULT '0',
  "notes" VARCHAR NOT NULL,
  "ID_admin" INTEGER DEFAULT NULL,
  "status_check" SMALLINT NOT NULL DEFAULT 0,
  "timestamp_check" TIMESTAMP DEFAULT NULL-- UNIQUE KEY "ID_sitio_UNIQUE" ("ID_sitio"),
-- KEY "hc_id_admin_idx" ("ID_admin"),
-- CONSTRAINT "hc_id_admin" FOREIGN KEY ("ID_admin") REFERENCES "daily_users" ("ID_user"),
-- CONSTRAINT "hc_id_site" FOREIGN KEY ("ID_sitio") REFERENCES "daily_sites" ("ID_site")
);


-- ----------------------------------------------------------
-- Tabla: daily_hc_tickets
-- ----------------------------------------------------------
DROP TABLE IF EXISTS "daily_hc_tickets";
CREATE TABLE "daily_hc_tickets" (
  "ID_ticket" INTEGER NOT NULL,
  "ID_sitio" INTEGER NOT NULL,
  "ID_supervisor" INTEGER NOT NULL,
  PRIMARY KEY ("ID_ticket")-- UNIQUE KEY "ID_ticket_UNIQUE" ("ID_ticket"),
-- KEY "hc_ticket_id_supervisor_idx" ("ID_supervisor"),
-- KEY "hc_ticket_id_site_idx" ("ID_sitio"),
-- CONSTRAINT "hc_ticket_id_site" FOREIGN KEY ("ID_sitio") REFERENCES "daily_sites" ("ID_site"),
-- CONSTRAINT "hc_ticket_id_supervisor" FOREIGN KEY ("ID_supervisor") REFERENCES "daily_users" ("ID_user")
);


-- ----------------------------------------------------------
-- Tabla: daily_help_solicitudes
-- ----------------------------------------------------------
DROP TABLE IF EXISTS "daily_help_solicitudes";
CREATE TABLE "daily_help_solicitudes" (
  "ID_help_solicitude" INTEGER NOT NULL,
  "ID_user" INTEGER NOT NULL,
  "ID_station" INTEGER NOT NULL,
  "help_datetime" TIMESTAMP NOT NULL,
  "active" SMALLINT NOT NULL,
  PRIMARY KEY ("ID_help_solicitude")-- KEY "help_user_idx" ("ID_user"),
-- KEY "help_station_idx" ("ID_station"),
-- CONSTRAINT "help_station" FOREIGN KEY ("ID_station") REFERENCES "daily_stations_info" ("ID_station"),
-- CONSTRAINT "help_user" FOREIGN KEY ("ID_user") REFERENCES "daily_users" ("ID_user")
);


-- ----------------------------------------------------------
-- Tabla: daily_news
-- ----------------------------------------------------------
DROP TABLE IF EXISTS "daily_news";
CREATE TABLE "daily_news" (
  "ID_news" INTEGER NOT NULL,
  "news_type" VARCHAR NOT NULL,
  "news_info" VARCHAR NOT NULL,
  "news_urgency" VARCHAR NOT NULL,
  "ID_user" INTEGER NOT NULL,
  "news_datetime_in" TIMESTAMP NOT NULL,
  "news_datetime_out" TIMESTAMP DEFAULT NULL,
  "active" SMALLINT NOT NULL,
  PRIMARY KEY ("ID_news")-- KEY "news_id_supervisor_idx" ("ID_user"),
-- CONSTRAINT "news_id_supervisor" FOREIGN KEY ("ID_user") REFERENCES "daily_users" ("ID_user")
);


-- ----------------------------------------------------------
-- Tabla: daily_season_offsets
-- ----------------------------------------------------------
DROP TABLE IF EXISTS "daily_season_offsets";
CREATE TABLE "daily_season_offsets" (
  "ID_season" INTEGER NOT NULL,
  "season_offsets" VARCHAR NOT NULL,
  "active" SMALLINT NOT NULL,
  "season_datetime_in" TIMESTAMP NOT NULL,
  "season_datetime_out" TIMESTAMP NOT NULL,
  PRIMARY KEY ("ID_season")
);


-- ----------------------------------------------------------
-- Tabla: daily_sesions
-- ----------------------------------------------------------
DROP TABLE IF EXISTS "daily_sesions";
CREATE TABLE "daily_sesions" (
  "ID_sesion" INTEGER NOT NULL,
  "ID_user" INTEGER NOT NULL,
  "sesion_in" TIMESTAMP NOT NULL,
  "ID_station" INTEGER NOT NULL,
  "sesion_out" TIMESTAMP DEFAULT NULL,
  "sesion_active" SMALLINT NOT NULL,
  "sesion_status" SMALLINT DEFAULT NULL,
  PRIMARY KEY ("ID_sesion")-- KEY "ses_id_user_idx" ("ID_user"),
-- KEY "ses_id_station_idx" ("ID_station"),
-- CONSTRAINT "ses_id_station" FOREIGN KEY ("ID_station") REFERENCES "daily_stations_info" ("ID_station"),
-- CONSTRAINT "ses_id_user" FOREIGN KEY ("ID_user") REFERENCES "daily_users" ("ID_user")
);
















-- ----------------------------------------------------------
-- Tabla: daily_sites
-- ----------------------------------------------------------
DROP TABLE IF EXISTS "daily_sites";
CREATE TABLE "daily_sites" (
  "ID_site" INTEGER NOT NULL,
  "ID_group" VARCHAR NOT NULL,
  "site_name" VARCHAR NOT NULL,
  "site_timezone" VARCHAR NOT NULL,
  "site_dns" VARCHAR DEFAULT NULL,
  "site_ip" VARCHAR DEFAULT NULL,
  "site_vms" VARCHAR NOT NULL DEFAULT 'OMNIA',
  PRIMARY KEY ("ID_site")
);


-- ----------------------------------------------------------
-- Tabla: daily_specials
-- ----------------------------------------------------------
DROP TABLE IF EXISTS "daily_specials";
CREATE TABLE "daily_specials" (
  "ID_special" INTEGER NOT NULL,
  "spec_datetime" TIMESTAMP NOT NULL,
  "ID_site" INTEGER NOT NULL,
  "ID_activity" INTEGER NOT NULL,
  "spec_quantity" VARCHAR DEFAULT NULL,
  "spec_camera" VARCHAR DEFAULT NULL,
  "spec_description" VARCHAR DEFAULT NULL,
  "ID_supervisor" INTEGER NOT NULL,
  "spec_status" VARCHAR DEFAULT NULL,
  "spec_marked_at" TIMESTAMP DEFAULT NULL,
  "spec_marked_by" INTEGER DEFAULT NULL,
  "ID_event" INTEGER NOT NULL,
  "ID_user" INTEGER NOT NULL,
  PRIMARY KEY ("ID_special")-- UNIQUE KEY "ID_event_UNIQUE" ("ID_event"),
-- KEY "spec_id_site_idx" ("ID_site"),
-- KEY "spec_id_activity_idx" ("ID_activity"),
-- KEY "spec_id_supervisor_idx" ("ID_supervisor"),
-- KEY "spec__id_user_idx" ("ID_user"),
-- KEY "spec_id_marked_by_idx" ("spec_marked_by"),
-- CONSTRAINT "spec__id_user" FOREIGN KEY ("ID_user") REFERENCES "daily_users" ("ID_user"),
-- CONSTRAINT "spec_id_activity" FOREIGN KEY ("ID_activity") REFERENCES "daily_activities" ("ID_Activity"),
-- CONSTRAINT "spec_id_marked_by" FOREIGN KEY ("spec_marked_by") REFERENCES "daily_users" ("ID_user"),
-- CONSTRAINT "spec_id_site" FOREIGN KEY ("ID_site") REFERENCES "daily_sites" ("ID_site"),
-- CONSTRAINT "spec_id_supervisor" FOREIGN KEY ("ID_supervisor") REFERENCES "daily_users" ("ID_user")
);






















-- ----------------------------------------------------------
-- Tabla: daily_special_groups
-- ----------------------------------------------------------
DROP TABLE IF EXISTS "daily_special_groups";
CREATE TABLE "daily_special_groups" (
  "ID_site_special" INTEGER NOT NULL,
  "site_group_special" VARCHAR NOT NULL,
  PRIMARY KEY ("ID_site_special")
);


-- ----------------------------------------------------------
-- Tabla: daily_stations_info
-- ----------------------------------------------------------
DROP TABLE IF EXISTS "daily_stations_info";
CREATE TABLE "daily_stations_info" (
  "ID_station" INTEGER NOT NULL,
  "station_number" VARCHAR NOT NULL,
  "ID_station_rol" INTEGER NOT NULL DEFAULT 1,
  PRIMARY KEY ("ID_station")-- KEY "station_rol_type_idx" ("ID_station_rol"),
-- CONSTRAINT "ID_station_rol_type" FOREIGN KEY ("ID_station_rol") REFERENCES "daily_stations_rol_types" ("ID_station_rol")
);


-- ----------------------------------------------------------
-- Tabla: daily_stations_map
-- ----------------------------------------------------------
DROP TABLE IF EXISTS "daily_stations_map";
CREATE TABLE "daily_stations_map" (
  "station_ID" INTEGER NOT NULL,
  "station_user" INTEGER DEFAULT NULL,
  "is_active" SMALLINT DEFAULT NULL,
  "station_alert" SMALLINT DEFAULT 0,
  PRIMARY KEY ("station_ID")-- CONSTRAINT "stations_id" FOREIGN KEY ("station_ID") REFERENCES "daily_stations_info" ("ID_station")
);


-- ----------------------------------------------------------
-- Tabla: daily_stations_rol_types
-- ----------------------------------------------------------
DROP TABLE IF EXISTS "daily_stations_rol_types";
CREATE TABLE "daily_stations_rol_types" (
  "ID_station_rol" INTEGER NOT NULL,
  "station_rol_type" VARCHAR NOT NULL,
  PRIMARY KEY ("ID_station_rol")
);


-- ----------------------------------------------------------
-- Tabla: daily_stations_visual_config
-- ----------------------------------------------------------
DROP TABLE IF EXISTS "daily_stations_visual_config";
CREATE TABLE "daily_stations_visual_config" (
  "ID_config" INTEGER NOT NULL,
  "ID_station" INTEGER NOT NULL ,
  "map_position_x" INTEGER NOT NULL ,
  "map_position_y" INTEGER NOT NULL ,
  "indicator_side" VARCHAR NOT NULL ,
  "indicator_offset_x" INTEGER NOT NULL DEFAULT 45 ,
  "indicator_radius" INTEGER NOT NULL DEFAULT 5 ,
  "emoji_offset_x" INTEGER NOT NULL DEFAULT 70 ,
  "emoji_font_size" INTEGER NOT NULL DEFAULT 24 ,
  "station_type" VARCHAR NOT NULL DEFAULT 'OPERATOR',
  "display_order" INTEGER NOT NULL DEFAULT 0 ,
  "is_visible" SMALLINT NOT NULL DEFAULT 1 ,
  "created_at" timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ,
  "updated_by" INTEGER DEFAULT NULL ,
  PRIMARY KEY ("ID_config")-- UNIQUE KEY "uk_station_config" ("ID_station"),
-- KEY "fk_visual_config_user" ("updated_by"),
-- KEY "idx_station_type" ("station_type"),
-- KEY "idx_visible_stations" ("is_visible","display_order"),
-- KEY "idx_updated_at" ("updated_at"),
-- CONSTRAINT "fk_visual_config_station" FOREIGN KEY ("ID_station") REFERENCES "daily_stations_info" ("ID_station") ON DELETE CASCADE,
-- CONSTRAINT "fk_visual_config_user" FOREIGN KEY ("updated_by") REFERENCES "daily_users" ("ID_user") ON DELETE SET NULL
);


-- ----------------------------------------------------------
-- Tabla: daily_station_messages
-- ----------------------------------------------------------
DROP TABLE IF EXISTS "daily_station_messages";
CREATE TABLE "daily_station_messages" (
  "ID_message" INTEGER NOT NULL,
  "ID_sender_user" INTEGER NOT NULL,
  "ID_station_target" INTEGER NOT NULL,
  "message_type" VARCHAR NOT NULL DEFAULT 'info',
  "message_title" VARCHAR NOT NULL,
  "message_body" text NOT NULL,
  "created_at" timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "read_at" timestamp NULL DEFAULT NULL,
  "is_active" SMALLINT NOT NULL DEFAULT 1,
  PRIMARY KEY ("ID_message")-- KEY "idx_station_active" ("ID_station_target","is_active","read_at"),
-- KEY "idx_sender" ("ID_sender_user"),
-- KEY "idx_created" ("created_at"),
-- CONSTRAINT "daily_station_messages_ibfk_1" FOREIGN KEY ("ID_sender_user") REFERENCES "daily_users" ("ID_user")
);


-- ----------------------------------------------------------
-- Tabla: daily_summer_offsets
-- ----------------------------------------------------------
DROP TABLE IF EXISTS "daily_summer_offsets";
CREATE TABLE "daily_summer_offsets" (
  "ID_time_offset" INTEGER NOT NULL,
  "time_zone" VARCHAR NOT NULL,
  "time_offset" INTEGER NOT NULL,
  PRIMARY KEY ("ID_time_offset")
);


-- ----------------------------------------------------------
-- Tabla: daily_supervisor_stations_ranges
-- ----------------------------------------------------------
DROP TABLE IF EXISTS "daily_supervisor_stations_ranges";
CREATE TABLE "daily_supervisor_stations_ranges" (
  "ID_station_range" INTEGER NOT NULL,
  "ID_station_start" INTEGER NOT NULL,
  "ID_station_end" INTEGER NOT NULL,
  "ID_supervisor_station" INTEGER NOT NULL,
  "active" SMALLINT NOT NULL,
  "created_at" TIMESTAMP NOT NULL,
  PRIMARY KEY ("ID_station_range")
);


-- ----------------------------------------------------------
-- Tabla: daily_supervisor_station_selection
-- ----------------------------------------------------------
DROP TABLE IF EXISTS "daily_supervisor_station_selection";
CREATE TABLE "daily_supervisor_station_selection" (
  "ID_manual_selection" INTEGER NOT NULL,
  "ID_supevisor_station" INTEGER NOT NULL,
  "ID_user_station" INTEGER NOT NULL,
  "selec_datetime" TIMESTAMP NOT NULL,
  "active" SMALLINT NOT NULL,
  PRIMARY KEY ("ID_manual_selection")
);


-- ----------------------------------------------------------
-- Tabla: daily_teamviewer_connection_log
-- ----------------------------------------------------------
DROP TABLE IF EXISTS "daily_teamviewer_connection_log";
CREATE TABLE "daily_teamviewer_connection_log" (
  "ID_connection_log" INTEGER NOT NULL,
  "ID_station" INTEGER NOT NULL,
  "ID_user" INTEGER NOT NULL ,
  "connection_datetime" timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "connection_status" VARCHAR DEFAULT 'SUCCESS',
  "error_message" text DEFAULT NULL,
  PRIMARY KEY ("ID_connection_log")-- KEY "tv_log_user_fk" ("ID_user"),
-- KEY "idx_connection_datetime" ("connection_datetime"),
-- KEY "idx_station_user" ("ID_station","ID_user"),
-- CONSTRAINT "tv_log_station_fk" FOREIGN KEY ("ID_station") REFERENCES "daily_teamviewer_stations" ("ID_station") ON DELETE CASCADE,
-- CONSTRAINT "tv_log_user_fk" FOREIGN KEY ("ID_user") REFERENCES "daily_users" ("ID_user") ON DELETE CASCADE
);


-- ----------------------------------------------------------
-- Tabla: daily_teamviewer_stations
-- ----------------------------------------------------------
DROP TABLE IF EXISTS "daily_teamviewer_stations";
CREATE TABLE "daily_teamviewer_stations" (
  "ID_station" INTEGER NOT NULL,
  "teamviewer_device_id" VARCHAR NOT NULL ,
  "teamviewer_alias" VARCHAR DEFAULT NULL ,
  "is_online" SMALLINT DEFAULT 0 ,
  "last_connection" timestamp NULL DEFAULT NULL ,
  "created_at" timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ,
  PRIMARY KEY ("ID_station")-- UNIQUE KEY "unique_device_id" ("teamviewer_device_id"),
-- KEY "idx_is_online" ("is_online"),
-- KEY "idx_last_connection" ("last_connection"),
-- CONSTRAINT "tv_station_fk" FOREIGN KEY ("ID_station") REFERENCES "daily_stations_info" ("ID_station") ON DELETE CASCADE ON UPDATE CASCADE
);


-- ----------------------------------------------------------
-- Tabla: daily_users
-- ----------------------------------------------------------
DROP TABLE IF EXISTS "daily_users";
CREATE TABLE "daily_users" (
  "ID_user" INTEGER NOT NULL,
  "ID_user_rol" INTEGER NOT NULL,
  "user_password" VARCHAR NOT NULL,
  "active" SMALLINT NOT NULL,
  PRIMARY KEY ("ID_user")-- KEY "user_rol_idx" ("ID_user_rol"),
-- CONSTRAINT "user_name" FOREIGN KEY ("ID_user") REFERENCES "daily_users_names" ("ID_user"),
-- CONSTRAINT "user_rol" FOREIGN KEY ("ID_user_rol") REFERENCES "daily_user_rol" ("ID_user_rol")
);


-- ----------------------------------------------------------
-- Tabla: daily_users_groups
-- ----------------------------------------------------------
DROP TABLE IF EXISTS "daily_users_groups";
CREATE TABLE "daily_users_groups" (
  "ID_user_group" INTEGER NOT NULL,
  "user_group_name" VARCHAR NOT NULL,
  PRIMARY KEY ("ID_user_group")
);


-- ----------------------------------------------------------
-- Tabla: daily_users_names
-- ----------------------------------------------------------
DROP TABLE IF EXISTS "daily_users_names";
CREATE TABLE "daily_users_names" (
  "ID_user" INTEGER NOT NULL,
  "user_name" VARCHAR NOT NULL,
  PRIMARY KEY ("ID_user")
);


-- ----------------------------------------------------------
-- Tabla: daily_user_rol
-- ----------------------------------------------------------
DROP TABLE IF EXISTS "daily_user_rol";
CREATE TABLE "daily_user_rol" (
  "ID_user_rol" INTEGER NOT NULL,
  "user_rol_name" VARCHAR NOT NULL,
  PRIMARY KEY ("ID_user_rol")
);


-- ----------------------------------------------------------
-- Tabla: daily_winter_offsets
-- ----------------------------------------------------------
DROP TABLE IF EXISTS "daily_winter_offsets";
CREATE TABLE "daily_winter_offsets" (
  "ID_time_offset" INTEGER NOT NULL,
  "time_zone" VARCHAR NOT NULL,
  "time_offset" INTEGER NOT NULL,
  PRIMARY KEY ("ID_time_offset")
);


-- ----------------------------------------------------------
-- Tabla: django_admin_log
-- ----------------------------------------------------------
DROP TABLE IF EXISTS "django_admin_log";
CREATE TABLE "django_admin_log" (
  "id" INTEGER NOT NULL,
  "action_time" TIMESTAMP NOT NULL,
  "object_id" TEXT DEFAULT NULL,
  "object_repr" VARCHAR NOT NULL,
  "action_flag" SMALLINT  NOT NULL CHECK ("action_flag" >= 0),
  "change_message" TEXT NOT NULL,
  "content_type_id" INTEGER DEFAULT NULL,
  "user_id" INTEGER NOT NULL,
  PRIMARY KEY ("id")-- KEY "django_admin_log_content_type_id_c4bce8eb_fk_django_co" ("content_type_id"),
-- KEY "django_admin_log_user_id_c564eba6_fk_auth_user_id" ("user_id"),
-- CONSTRAINT "django_admin_log_content_type_id_c4bce8eb_fk_django_co" FOREIGN KEY ("content_type_id") REFERENCES "django_content_type" ("id"),
-- CONSTRAINT "django_admin_log_user_id_c564eba6_fk_auth_user_id" FOREIGN KEY ("user_id") REFERENCES "auth_user" ("id")
);


-- ----------------------------------------------------------
-- Tabla: django_content_type
-- ----------------------------------------------------------
DROP TABLE IF EXISTS "django_content_type";
CREATE TABLE "django_content_type" (
  "id" INTEGER NOT NULL,
  "app_label" VARCHAR NOT NULL,
  "model" VARCHAR NOT NULL,
  PRIMARY KEY ("id")-- UNIQUE KEY "django_content_type_app_label_model_76bd3d3b_uniq" ("app_label","model")
);


-- ----------------------------------------------------------
-- Tabla: django_migrations
-- ----------------------------------------------------------
DROP TABLE IF EXISTS "django_migrations";
CREATE TABLE "django_migrations" (
  "id" BIGINT NOT NULL,
  "app" VARCHAR NOT NULL,
  "name" VARCHAR NOT NULL,
  "applied" TIMESTAMP NOT NULL,
  PRIMARY KEY ("id")
);


-- ----------------------------------------------------------
-- Tabla: django_session
-- ----------------------------------------------------------
DROP TABLE IF EXISTS "django_session";
CREATE TABLE "django_session" (
  "session_key" VARCHAR NOT NULL,
  "session_data" TEXT NOT NULL,
  "expire_date" TIMESTAMP NOT NULL,
  PRIMARY KEY ("session_key")-- KEY "django_session_expire_date_a5c62663" ("expire_date")
);


-- ----------------------------------------------------------
-- Tabla: platform_tools
-- ----------------------------------------------------------
DROP TABLE IF EXISTS "platform_tools";
CREATE TABLE "platform_tools" (
  "id" BIGINT NOT NULL,
  "slug" VARCHAR NOT NULL,
  "name" VARCHAR NOT NULL,
  "description" VARCHAR NOT NULL,
  "frontend_url" VARCHAR NOT NULL,
  "icon" VARCHAR NOT NULL,
  "is_active" SMALLINT NOT NULL,
  "order" SMALLINT  NOT NULL CHECK ("order" >= 0),
  "created_at" TIMESTAMP NOT NULL,
  PRIMARY KEY ("id")-- UNIQUE KEY "slug" ("slug")
);


-- ----------------------------------------------------------
-- Tabla: platform_user_tool_access
-- ----------------------------------------------------------
DROP TABLE IF EXISTS "platform_user_tool_access";
CREATE TABLE "platform_user_tool_access" (
  "id" BIGINT NOT NULL,
  "is_active" SMALLINT NOT NULL,
  "granted_at" TIMESTAMP NOT NULL,
  "tool_id" BIGINT NOT NULL,
  "user_id" INTEGER NOT NULL,
  PRIMARY KEY ("id")-- UNIQUE KEY "platform_user_tool_access_user_id_tool_id_71cb8c98_uniq" ("user_id","tool_id"),
-- KEY "platform_user_tool_access_tool_id_5f22f514_fk_platform_tools_id" ("tool_id"),
-- CONSTRAINT "platform_user_tool_access_tool_id_5f22f514_fk_platform_tools_id" FOREIGN KEY ("tool_id") REFERENCES "platform_tools" ("id"),
-- CONSTRAINT "platform_user_tool_access_user_id_84c9ca14_fk_auth_user_id" FOREIGN KEY ("user_id") REFERENCES "auth_user" ("id")
);

-- (sin registros)

-- ----------------------------------------------------------
-- Tabla: sig_projects
-- ----------------------------------------------------------
DROP TABLE IF EXISTS "sig_projects";
CREATE TABLE "sig_projects" (
  "id" char(32) NOT NULL,
  "name" VARCHAR NOT NULL,
  "data" TEXT   NOT NULL ,
  "version" INTEGER NOT NULL,
  "owner_id" BIGINT DEFAULT NULL,
  "created_at" TIMESTAMP NOT NULL,
  "updated_at" TIMESTAMP NOT NULL,
  PRIMARY KEY ("id")
);


-- ----------------------------------------------------------
-- Tabla: token_blacklist_blacklistedtoken
-- ----------------------------------------------------------
DROP TABLE IF EXISTS "token_blacklist_blacklistedtoken";
CREATE TABLE "token_blacklist_blacklistedtoken" (
  "id" BIGINT NOT NULL,
  "blacklisted_at" TIMESTAMP NOT NULL,
  "token_id" BIGINT NOT NULL,
  PRIMARY KEY ("id")-- UNIQUE KEY "token_id" ("token_id"),
-- CONSTRAINT "token_blacklist_blacklistedtoken_token_id_3cc7fe56_fk" FOREIGN KEY ("token_id") REFERENCES "token_blacklist_outstandingtoken" ("id")
);


-- ----------------------------------------------------------
-- Tabla: token_blacklist_outstandingtoken
-- ----------------------------------------------------------
DROP TABLE IF EXISTS "token_blacklist_outstandingtoken";
CREATE TABLE "token_blacklist_outstandingtoken" (
  "id" BIGINT NOT NULL,
  "token" TEXT NOT NULL,
  "created_at" TIMESTAMP DEFAULT NULL,
  "expires_at" TIMESTAMP NOT NULL,
  "user_id" INTEGER DEFAULT NULL,
  "jti" VARCHAR NOT NULL,
  PRIMARY KEY ("id")-- UNIQUE KEY "token_blacklist_outstandingtoken_jti_hex_d9bdf6f7_uniq" ("jti"),
-- KEY "token_blacklist_outs_user_id_83bc629a_fk_auth_user" ("user_id"),
-- CONSTRAINT "token_blacklist_outs_user_id_83bc629a_fk_auth_user" FOREIGN KEY ("user_id") REFERENCES "auth_user" ("id")
);


-- SET FOREIGN_KEY_CHECKS = 1;
-- Fin del dump — 2026-05-12 01:56:12
