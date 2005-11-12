CREATE TABLE tags (
	id		SERIAL PRIMARY KEY,
	
	tag		VARCHAR(512),
	
	account		INTEGER NOT NULL,
	site		INTEGER NOT NULL,

	level		INTEGER NOT NULL DEFAULT 0,
	viewing		INTEGER NOT NULL DEFAULT 0,

	journals_auth	INTEGER NOT NULL,

	created		TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX tags_j_a_idx ON tags (journals_auth);
CREATE INDEX tags_account_idx ON tags (account);