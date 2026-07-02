CREATE TABLE `session_plan_overrides` (
	`id` text PRIMARY KEY NOT NULL,
	`session_id` text NOT NULL,
	`routine_exercise_id` text NOT NULL,
	`replaced_exercise_id` text NOT NULL,
	`reason` text,
	`is_deleted` integer DEFAULT 0 NOT NULL,
	`created_at` text NOT NULL
);
--> statement-breakpoint
CREATE INDEX `session_plan_overrides_session_idx` ON `session_plan_overrides` (`session_id`);