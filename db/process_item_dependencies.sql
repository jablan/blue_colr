CREATE TABLE process_item_dependencies (
process_item_id INT NOT NULL REFERENCES process_items (id),
depends_on_id INT NOT NULL REFERENCES process_items (id)
);

ALTER TABLE process_item_dependencies ADD PRIMARY KEY (process_item_id, depends_on_id);