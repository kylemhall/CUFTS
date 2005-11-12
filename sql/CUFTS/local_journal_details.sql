CREATE TABLE local_journal_details (
	id		SERIAL PRIMARY KEY,

	local_journal	INTEGER NOT NULL,		/* id for local journal */

	field		VARCHAR(128),
	value		VARCHAR(8192),
	
	created		TIMESTAMP NOT NULL DEFAULT NOW(),
	modified	TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX local_journal_details_journal_idx ON local_journal_details(local_journal);
