CREATE TABLE titles (
	id		SERIAL PRIMARY KEY,
	journal		INTEGER NOT NULL,
	title		VARCHAR(512) NOT NULL,
	search_title	VARCHAR(512) NOT NULL,
	site		INTEGER NOT NULL,
	main		INTEGER NOT NULL DEFAULT 0
);

CREATE INDEX titles_journal ON titles (journal);
CREATE INDEX titles_site_search_title ON titles (site, search_title varchar_pattern_ops);