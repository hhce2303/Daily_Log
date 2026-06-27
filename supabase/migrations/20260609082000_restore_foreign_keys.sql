ALTER TABLE "daily_events" ADD CONSTRAINT "event_id_activity" FOREIGN KEY ("ID_activity") REFERENCES "daily_activities" ("ID_Activity");
ALTER TABLE "daily_events" ADD CONSTRAINT "event_id_site" FOREIGN KEY ("ID_site") REFERENCES "daily_sites" ("ID_site");
ALTER TABLE "daily_events" ADD CONSTRAINT "event_id_user" FOREIGN KEY ("ID_user") REFERENCES "daily_users" ("ID_user");

ALTER TABLE "daily_specials" ADD CONSTRAINT "specials_id_activity" FOREIGN KEY ("ID_activity") REFERENCES "daily_activities" ("ID_Activity");
ALTER TABLE "daily_specials" ADD CONSTRAINT "specials_id_site" FOREIGN KEY ("ID_site") REFERENCES "daily_sites" ("ID_site");
ALTER TABLE "daily_specials" ADD CONSTRAINT "specials_id_user" FOREIGN KEY ("ID_user") REFERENCES "daily_users" ("ID_user");
ALTER TABLE "daily_specials" ADD CONSTRAINT "specials_id_supervisor" FOREIGN KEY ("ID_supervisor") REFERENCES "daily_users" ("ID_user");