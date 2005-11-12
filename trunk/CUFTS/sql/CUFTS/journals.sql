CREATE TABLE journals (
	id		SERIAL PRIMARY KEY,
	title		VARCHAR(512),
	issn		VARCHAR(8),		/* ISSN with no dash */
	e_issn		VARCHAR(8),		/* Electronic ISSN if one exists (no dash) */

	resource	INTEGER NOT NULL,	/* id for resource journal is in */
	
	vol_cit_start	VARCHAR(128),		/* Starting volume for citations */
	vol_cit_end	VARCHAR(128),		/* Ending volume for citations */
	vol_ft_start	VARCHAR(128),		/* Starting volume for fulltext */
	vol_ft_end	VARCHAR(128),		/* Ending volume for fulltext */

	iss_cit_start	VARCHAR(128),		/* Starting issue for citations */
	iss_cit_end	VARCHAR(128),		/* Ending issue for citations */
	iss_ft_start	VARCHAR(128),		/* Starting issue for fulltext */
	iss_ft_end	VARCHAR(128),		/* Ending issue for fulltext */

	cit_start_date	DATE,			/* Starting date for citations */
	cit_end_date	DATE,			/* Ending date for citations */
	ft_start_date	DATE,			/* Starting date for fulltext */
	ft_end_date	DATE,			/* Ending date for fulltext */

	embargo_months	INTEGER,		/* Number of months title is embargoed */
	embargo_days	INTEGER,		/* Number of days title is embargoed */

	journal_auth	INTEGER,		/* Link to the journal auth table */

	created		TIMESTAMP NOT NULL DEFAULT NOW(),
	scanned		TIMESTAMP NOT NULL DEFAULT NOW(),
	modified	TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX journals_issn_idx ON journals (issn);
CREATE INDEX journals_title_idx ON journals (title);
CREATE INDEX journals_e_issn_idx ON journals (e_issn);
CREATE INDEX journals_resource_idx ON journals (resource);
CREATE INDEX journals_journal_auth_idx ON journals (journal_auth);