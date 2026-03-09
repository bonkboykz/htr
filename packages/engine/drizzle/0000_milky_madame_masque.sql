CREATE TABLE `daily_targets` (
	`id` text PRIMARY KEY NOT NULL,
	`effective_date` text NOT NULL,
	`calories` integer NOT NULL,
	`protein` integer NOT NULL,
	`fat` integer NOT NULL,
	`carbs` integer NOT NULL,
	`water_ml` integer DEFAULT 2500 NOT NULL,
	`sleep_minutes` integer DEFAULT 480 NOT NULL,
	`is_deleted` integer DEFAULT 0 NOT NULL,
	`created_at` text NOT NULL
);
--> statement-breakpoint
CREATE TABLE `food_items` (
	`id` text PRIMARY KEY NOT NULL,
	`name` text NOT NULL,
	`brand` text,
	`calories_per_100g` integer NOT NULL,
	`protein_per_100g` integer NOT NULL,
	`fat_per_100g` integer NOT NULL,
	`carbs_per_100g` integer NOT NULL,
	`fiber_per_100g` integer DEFAULT 0 NOT NULL,
	`serving_size_g` integer DEFAULT 100 NOT NULL,
	`barcode` text,
	`is_deleted` integer DEFAULT 0 NOT NULL,
	`created_at` text NOT NULL
);
--> statement-breakpoint
CREATE TABLE `food_logs` (
	`id` text PRIMARY KEY NOT NULL,
	`date` text NOT NULL,
	`meal_id` text NOT NULL,
	`food_item_id` text NOT NULL,
	`serving_grams` integer NOT NULL,
	`calories` integer NOT NULL,
	`protein` integer NOT NULL,
	`fat` integer NOT NULL,
	`carbs` integer NOT NULL,
	`fiber` integer DEFAULT 0 NOT NULL,
	`is_deleted` integer DEFAULT 0 NOT NULL,
	`created_at` text NOT NULL
);
--> statement-breakpoint
CREATE TABLE `meals` (
	`id` text PRIMARY KEY NOT NULL,
	`name` text NOT NULL,
	`sort_order` integer NOT NULL,
	`is_system` integer DEFAULT 0 NOT NULL,
	`is_deleted` integer DEFAULT 0 NOT NULL,
	`created_at` text NOT NULL
);
--> statement-breakpoint
CREATE TABLE `sleep_logs` (
	`id` text PRIMARY KEY NOT NULL,
	`start_time` text NOT NULL,
	`end_time` text NOT NULL,
	`quality` integer,
	`note` text,
	`is_deleted` integer DEFAULT 0 NOT NULL,
	`created_at` text NOT NULL
);
--> statement-breakpoint
CREATE TABLE `water_logs` (
	`id` text PRIMARY KEY NOT NULL,
	`date` text NOT NULL,
	`amount_ml` integer NOT NULL,
	`is_deleted` integer DEFAULT 0 NOT NULL,
	`created_at` text NOT NULL
);
--> statement-breakpoint
CREATE TABLE `weight_logs` (
	`id` text PRIMARY KEY NOT NULL,
	`date` text NOT NULL,
	`weight_grams` integer NOT NULL,
	`body_fat` integer,
	`note` text,
	`is_deleted` integer DEFAULT 0 NOT NULL,
	`created_at` text NOT NULL
);
