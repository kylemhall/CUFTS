CREATE TABLE cjdb_subjects (
	id              SERIAL PRIMARY KEY,
	journal         INTEGER NOT NULL,
	subject         VARCHAR(512) NOT NULL,
	search_subject  VARCHAR(512) NOT NULL,
	origin          VARCHAR(512),
	level           INTEGER,
	site            INTEGER NOT NULL
);

CREATE INDEX cjdb_sub_journal ON cjdb_subjects (journal);
CREATE INDEX cjdb_subjects_site_ss ON cjdb_subjects (site, search_subject varchar_pattern_ops);