CREATE TABLE links (
	id		SERIAL PRIMARY KEY,
	journal		INTEGER NOT NULL,
	name		VARCHAR(1024) NOT NULL,
	print_coverage	VARCHAR(2048),
	citation_coverage	VARCHAR(2048),
	fulltext_coverage	VARCHAR(2048),
	embargo		VARCHAR(2048),
	URL		VARCHAR(2048),
	resource	INTEGER,
	link_label	VARCHAR(1024),
	site		INTEGER,
	rank		INTEGER
);

CREATE INDEX links_journal ON links (journal);
