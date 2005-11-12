CREATE TABLE issns (
	id		SERIAL PRIMARY KEY,
	journal		INTEGER NOT NULL,
	site		INTEGER,
	issn		VARCHAR(8)
);

CREATE INDEX issns_journal ON issns (journal);
