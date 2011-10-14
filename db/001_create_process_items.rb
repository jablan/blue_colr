Sequel.migration do
  up do
    create_table(:process_items) do
      primary_key :id
      String :environment, :size => 128
      Integer :debug_level
      Time :queued_at
      Time :started_at
      Time :ended_at
      String :status, :size => 32
      Integer :exit_code
      String :log_file
      String :description
      String :chdir
      String :cmd, :text => true
      String :custom_logger, :size => 32

      index [:status, :queued_at]
      index :queued_at
    end
  end
  down do
    drop_table(:process_items)
  end
end

