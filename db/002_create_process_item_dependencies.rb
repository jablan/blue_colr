Sequel.migration do
  up do
    create_table(:process_item_dependencies) do
      foreign_key :process_item_id, :process_items
      foreign_key :depends_on_id, :process_items
    end
  end
  down do
    drop_table :process_item_dependencies
  end
end
