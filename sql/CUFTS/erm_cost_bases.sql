CREATE TABLE erm_cost_bases (
    id              SERIAL PRIMARY KEY,
    site            INTEGER,
    cost_base       VARCHAR(1024)
);

CREATE INDEX erm_cost_bases_site_idx ON erm_cost_bases (site);