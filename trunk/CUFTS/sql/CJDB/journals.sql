CREATE TABLE cjdb_journals (
	id              SERIAL PRIMARY KEY,
	title		    VARCHAR(1024) NOT NULL,
	sort_title	    VARCHAR(1024) NOT NULL,
	stripped_sort_title VARCHAR(1024) NOT NULL,
	call_number     VARCHAR(128),
	journals_auth   INTEGER,
	site            INTEGER NOT NULL,
	created         TIMESTAMP NOT NULL DEFAULT NOW()
);

create index cjdb_journals_st_idx on cjdb_journals (sort_title);
create index cjdb_journals_ja_idx on cjdb_journals (journals_auth);
