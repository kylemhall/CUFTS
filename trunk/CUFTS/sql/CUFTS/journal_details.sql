CREATE TABLE journal_details (
	id		SERIAL PRIMARY KEY,

	journal		INTEGER NOT NULL,		/* id for journal */

	field		VARCHAR(128),
	value		VARCHAR(8192),
	
	created		TIMESTAMP NOT NULL DEFAULT NOW(),
	modified	TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX journal_details_journal_idx ON journal_details(journal);
