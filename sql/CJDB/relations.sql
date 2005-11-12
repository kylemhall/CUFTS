CREATE TABLE relations (
	id		SERIAL PRIMARY KEY,
	journal		INTEGER NOT NULL,
	relation	VARCHAR(512) NOT NULL,
	title		VARCHAR(512) NOT NULL,
	issn		VARCHAR(8),
	site		INTEGER NOT NULL
);

CREATE INDEX relations_journal ON relations (journal);