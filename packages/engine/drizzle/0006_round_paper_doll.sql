CREATE TABLE `factor_categories` (
	`id` text PRIMARY KEY NOT NULL,
	`name` text NOT NULL,
	`emoji` text,
	`sort_order` integer DEFAULT 0 NOT NULL,
	`is_system` integer DEFAULT 0 NOT NULL,
	`is_deleted` integer DEFAULT 0 NOT NULL,
	`created_at` text NOT NULL
);
--> statement-breakpoint
CREATE TABLE `factor_logs` (
	`id` text PRIMARY KEY NOT NULL,
	`date` text NOT NULL,
	`factor_id` text NOT NULL,
	`value` integer NOT NULL,
	`note` text,
	`is_deleted` integer DEFAULT 0 NOT NULL,
	`created_at` text NOT NULL
);
--> statement-breakpoint
CREATE UNIQUE INDEX `factor_logs_factor_date_idx` ON `factor_logs` (`factor_id`,`date`);--> statement-breakpoint
CREATE INDEX `factor_logs_date_idx` ON `factor_logs` (`date`);--> statement-breakpoint
CREATE TABLE `factors` (
	`id` text PRIMARY KEY NOT NULL,
	`category_id` text NOT NULL,
	`name` text NOT NULL,
	`scale_min` integer DEFAULT 0 NOT NULL,
	`scale_max` integer DEFAULT 5 NOT NULL,
	`labels` text,
	`unit` text,
	`is_deleted` integer DEFAULT 0 NOT NULL,
	`created_at` text NOT NULL
);
