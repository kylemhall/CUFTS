CREATE TABLE associations (
	id			SERIAL PRIMARY KEY,
	journal			INTEGER NOT NULL,
	association		VARCHAR(512) NOT NULL,
	search_association	VARCHAR(512) NOT NULL,
	site			INTEGER NOT NULL
);

CREATE INDEX associations_journal ON associations (journal);
