CREATE TABLE resources (
	id		SERIAL PRIMARY KEY,
	name		VARCHAR(256) NOT NULL,

	resource_type	INTEGER NOT NULL,	/* id for resource type */

	provider	VARCHAR(256),
	module		VARCHAR(256) NOT NULL,

	active		BOOLEAN NOT NULL DEFAULT TRUE,
	
	title_list_scanned	TIMESTAMP,

	title_count	INTEGER,

	created		TIMESTAMP NOT NULL DEFAULT NOW(),
	modified	TIMESTAMP NOT NULL DEFAULT NOW()
);
