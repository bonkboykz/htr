ALTER TABLE `exercises` ADD `video_url` text;--> statement-breakpoint
ALTER TABLE `routine_exercises` ADD `is_optional` integer DEFAULT 0 NOT NULL;--> statement-breakpoint
UPDATE `exercises` SET `video_query` = 'barbell bench press form' WHERE `id` = 'ex-bench_press';--> statement-breakpoint
UPDATE `routine_exercises` SET `is_optional` = 1 WHERE `id` IN ('re-a-07', 're-a-08', 're-b-09', 're-b-10');