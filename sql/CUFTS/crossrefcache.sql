CREATE TABLE crossrefcache (
	id		    SERIAL PRIMARY KEY,

	query		TEXT,
	result		TEXT,

	created		TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX crossrefcache_query_idx ON crossrefcache (query);
