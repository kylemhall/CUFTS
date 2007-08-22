CREATE TABLE cjdb_roles (
    id      SERIAL PRIMARY KEY,
    role    VARCHAR(128)
);

INSERT INTO cjdb_roles (role) values ('edit_erm_records');