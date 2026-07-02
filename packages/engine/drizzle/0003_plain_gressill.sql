CREATE TABLE `exercises` (
	`id` text PRIMARY KEY NOT NULL,
	`name` text NOT NULL,
	`name_ru` text NOT NULL,
	`muscle_group` text NOT NULL,
	`pattern` text NOT NULL,
	`equipment` text NOT NULL,
	`is_unilateral` integer DEFAULT 0 NOT NULL,
	`is_safe_lower_back` integer DEFAULT 0 NOT NULL,
	`default_rep_min` integer NOT NULL,
	`default_rep_max` integer NOT NULL,
	`min_increment_g` integer NOT NULL,
	`video_query` text,
	`cues_ru` text,
	`is_deleted` integer DEFAULT 0 NOT NULL,
	`created_at` text NOT NULL
);
--> statement-breakpoint
CREATE TABLE `routine_exercises` (
	`id` text PRIMARY KEY NOT NULL,
	`routine_id` text NOT NULL,
	`exercise_id` text NOT NULL,
	`section` text NOT NULL,
	`sort_order` integer NOT NULL,
	`target_sets` integer NOT NULL,
	`rep_min` integer NOT NULL,
	`rep_max` integer NOT NULL,
	`target_rir` integer NOT NULL,
	`is_rampup_scaled` integer DEFAULT 0 NOT NULL,
	`notes` text,
	`is_deleted` integer DEFAULT 0 NOT NULL
);
--> statement-breakpoint
CREATE INDEX `routine_exercises_routine_section_sort_idx` ON `routine_exercises` (`routine_id`,`section`,`sort_order`);--> statement-breakpoint
CREATE TABLE `routines` (
	`id` text PRIMARY KEY NOT NULL,
	`name` text NOT NULL,
	`name_ru` text NOT NULL,
	`notes` text,
	`sort_order` integer NOT NULL,
	`is_deleted` integer DEFAULT 0 NOT NULL,
	`created_at` text NOT NULL
);
--> statement-breakpoint
CREATE TABLE `set_logs` (
	`id` text PRIMARY KEY NOT NULL,
	`session_id` text NOT NULL,
	`exercise_id` text NOT NULL,
	`set_number` integer NOT NULL,
	`weight_g` integer NOT NULL,
	`reps` integer NOT NULL,
	`rir` integer,
	`is_warmup` integer DEFAULT 0 NOT NULL,
	`is_deleted` integer DEFAULT 0 NOT NULL,
	`created_at` text NOT NULL
);
--> statement-breakpoint
CREATE INDEX `set_logs_exercise_created_idx` ON `set_logs` (`exercise_id`,`created_at`);--> statement-breakpoint
CREATE TABLE `workout_sessions` (
	`id` text PRIMARY KEY NOT NULL,
	`routine_id` text NOT NULL,
	`session_index` integer NOT NULL,
	`started_at` text NOT NULL,
	`ended_at` text,
	`notes` text,
	`is_deleted` integer DEFAULT 0 NOT NULL
);
--> statement-breakpoint
CREATE INDEX `workout_sessions_routine_started_idx` ON `workout_sessions` (`routine_id`,`started_at`);