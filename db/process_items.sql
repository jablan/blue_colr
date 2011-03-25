CREATE TABLE process_items (
id SERIAL PRIMARY KEY,
process_from timestamp,
environment varchar(128) default '',
debug_level smallint,
queued_at timestamp DEFAULT NOW(),
started_at timestamp,
ended_at timestamp,
status varchar(32),
exit_code smallint,
priority smallint,
log_file varchar(255),
description varchar(255),
chdir VARCHAR(255) DEFAULT NULL,
cmd text,
custom_logger VARCHAR(32)
);

CREATE INDEX i_process_items_queued_at ON process_items(queued_at DESC);
CREATE INDEX i_process_items_status ON process_items(status, queued_at DESC);
