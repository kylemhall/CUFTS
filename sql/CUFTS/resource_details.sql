CREATE TABLE resource_details (
	id		SERIAL PRIMARY KEY,

	resource	INTEGER NOT NULL,		/* id for resource */

	field		VARCHAR(128),
	value		VARCHAR(8192),
	
	created		TIMESTAMP NOT NULL DEFAULT NOW(),
	modified	TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX resource_details_resource_idx ON resource_details(resource);
