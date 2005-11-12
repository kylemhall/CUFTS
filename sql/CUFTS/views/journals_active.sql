CREATE VIEW journals_active AS
    SELECT local_journals.resource as local_resource, journals.id, journals.title, journals.issn, journals.e_issn, journals.resource, journals.vol_cit_start, journals.vol_cit_end, journals.vol_ft_start, journals.vol_ft_end, journals.iss_cit_start, journals.iss_cit_end, journals.iss_ft_start, journals.iss_ft_end, journals.cit_start_date, journals.cit_end_date, journals.ft_start_date, journals.ft_end_date, journals.embargo_months, journals.embargo_days, journals.journal_auth, journals.created, journals.scanned, journals.modified 
    FROM (journals JOIN local_journals ON ((local_journals.journal = journals.id))) 
    WHERE (local_journals.active = true);
