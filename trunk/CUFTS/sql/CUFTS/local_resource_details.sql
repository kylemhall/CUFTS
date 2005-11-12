CREATE TABLE local_resource_details (
	id		SERIAL PRIMARY KEY,

	local_resource	INTEGER NOT NULL,		/* id for local_resource */

	field		VARCHAR(128),
	value		VARCHAR(8192),
	
	created		TIMESTAMP NOT NULL DEFAULT NOW(),
	modified	TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX local_resource_details_local_resource_idx ON local_resource_details(local_resource);
