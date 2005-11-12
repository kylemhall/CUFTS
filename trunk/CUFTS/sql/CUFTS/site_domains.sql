CREATE TABLE site_domains (
	id		SERIAL PRIMARY KEY,

	site		INTEGER NOT NULL,
	domain		VARCHAR(256),	


	created		TIMESTAMP NOT NULL DEFAULT NOW(),
	modified	TIMESTAMP NOT NULL DEFAULT NOW()
);

