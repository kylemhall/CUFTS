CREATE TABLE local_resources (
	id		SERIAL PRIMARY KEY,
	site		INTEGER NOT NULL,

	name		VARCHAR(256),

	resource	INTEGER,		/* id for a global resource */

	provider	VARCHAR(256),

	resource_type	INTEGER,		/* id for resource type */

	proxy		BOOLEAN NOT NULL DEFAULT FALSE,		/* Proxy this resource? */
	dedupe		BOOLEAN NOT NULL DEFAULT FALSE,		/* Dedupe this resource? */
	auto_activate	BOOLEAN NOT NULL DEFAULT FALSE,		/* Autoactivate all titles? */

	rank		INTEGER DEFAULT 0,

	module		VARCHAR(256),

	active		BOOLEAN NOT NULL DEFAULT TRUE,
	
	title_list_scanned	TIMESTAMP,

	created		TIMESTAMP NOT NULL DEFAULT NOW(),
	modified	TIMESTAMP NOT NULL DEFAULT NOW()
);


CREATE INDEX local_resources_site_idx ON local_resources(site);