ALTER TABLE erm_main ADD COLUMN provider INTEGER;
ALTER TABLE erm_main ADD COLUMN provider_name VARCHAR(1024);
ALTER TABLE erm_main ADD COLUMN local_provider_name VARCHAR(1024);
ALTER TABLE erm_main ADD COLUMN provider_contact TEXT;
ALTER TABLE erm_main ADD COLUMN provider_notes TEXT;
ALTER TABLE erm_main ADD COLUMN support_email VARCHAR(1024);
ALTER TABLE erm_main ADD COLUMN support_phone VARCHAR(1024);
ALTER TABLE erm_main ADD COLUMN knowledgebase VARCHAR(1024);
ALTER TABLE erm_main ADD COLUMN customer_number VARCHAR(1024);
