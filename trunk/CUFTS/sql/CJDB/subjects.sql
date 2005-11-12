CREATE TABLE subjects (
	id		SERIAL PRIMARY KEY,
	journal		INTEGER NOT NULL,
	subject		VARCHAR(512) NOT NULL,
	search_subject	VARCHAR(512) NOT NULL,
	origin		VARCHAR(512),
	level		INTEGER,
	site		INTEGER NOT NULL
);

CREATE INDEX subjects_journal ON subjects (journal);