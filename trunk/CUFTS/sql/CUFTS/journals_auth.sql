CREATE TABLE journals_auth (
	id		SERIAL PRIMARY KEY,
	title		VARCHAR(1024),
	MARC		TEXT,

	active		BOOLEAN DEFAULT true,
	created		TIMESTAMP NOT NULL DEFAULT NOW(),
	modified	TIMESTAMP NOT NULL DEFAULT NOW()
);
