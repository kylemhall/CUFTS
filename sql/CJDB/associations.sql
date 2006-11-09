CREATE TABLE cjdb_associations (
	id			SERIAL PRIMARY KEY,
	journal			INTEGER NOT NULL,
	association		VARCHAR(512) NOT NULL,
	search_association	VARCHAR(512) NOT NULL,
	site			INTEGER NOT NULL
);

CREATE INDEX cjdb_assc_journal ON cjdb_associations (journal);
CREATE INDEX cjdb_associations_site_sa ON cjdb_associations (site, search_association varchar_pattern_ops);
