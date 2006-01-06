CREATE TABLE cjdb_titles (
	id              SERIAL PRIMARY KEY,
	journal         INTEGER NOT NULL,
	title           VARCHAR(512) NOT NULL,
	search_title    VARCHAR(512) NOT NULL,
	site            INTEGER NOT NULL,
	main            INTEGER NOT NULL DEFAULT 0
);

CREATE INDEX cjdb_titles_journal ON cjdb_titles (journal);
CREATE INDEX cjdb_titles_site_st ON cjdb_titles (site, search_title varchar_pattern_ops);