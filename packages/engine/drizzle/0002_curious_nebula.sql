CREATE TABLE `user_profile` (
	`id` text PRIMARY KEY NOT NULL,
	`height_cm` integer NOT NULL,
	`birth_date` text NOT NULL,
	`sex` text NOT NULL,
	`activity_level` text DEFAULT 'moderate' NOT NULL,
	`created_at` text NOT NULL,
	`updated_at` text NOT NULL
);
--> statement-breakpoint
CREATE TABLE `weight_goals` (
	`id` text PRIMARY KEY NOT NULL,
	`target_grams` integer NOT NULL,
	`pace` text DEFAULT 'normal' NOT NULL,
	`start_date` text NOT NULL,
	`start_grams` integer NOT NULL,
	`is_active` integer DEFAULT 1 NOT NULL,
	`is_deleted` integer DEFAULT 0 NOT NULL,
	`created_at` text NOT NULL
);
