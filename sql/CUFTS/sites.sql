CREATE TABLE sites (
	id		SERIAL PRIMARY KEY,
	key		VARCHAR(64),
	name		VARCHAR(256),

	proxy_prefix	VARCHAR(512),
	proxy_WAM   	VARCHAR(512),
	proxy_prefix_alternate	VARCHAR(512),
	email		VARCHAR(1024),

	active		BOOLEAN DEFAULT TRUE,

	created		TIMESTAMP NOT NULL DEFAULT NOW(),
	modified	TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX sites_key_idx on sites(key);

