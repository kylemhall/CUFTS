CREATE TABLE site_details (
	id		SERIAL PRIMARY KEY,

	site		INTEGER NOT NULL,		/* id for site */

	field		VARCHAR(128),
	value		VARCHAR(8192),
	
	created		TIMESTAMP NOT NULL DEFAULT NOW(),
	modified	TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX site_details_site_idx ON site_details(site);
