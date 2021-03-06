require 'mongify/translation/processor_common'
module Mongify
  class Translation
    #
    # This module does the processing on the translation object
    #
    include ProcessorCommon
    module Process
      # Does the actual act of processing the translation.
      # Takes in both a sql connection and a no sql connection
      def process(sql_connection, no_sql_connection)
        prepare_connections(sql_connection, no_sql_connection)
        setup_db_index
        copy_data
        copy_embedded_tables
        update_reference_ids
        copy_polymorphic_tables
        remove_pre_mongified_ids
        nil
      end

      #######
      private
      #######
      
      # Does the straight copy (of tables)
      def copy_data
        self.copy_tables.each do |t|
          rows = sql_connection.select_rows(t.sql_name)
          Mongify::Status.publish('copy_data', :size => rows.count, :name => "Copying #{t.name}", :action => 'add')
          rows.each do |row|
            no_sql_connection.insert_into(t.name, t.translate(row))
            Mongify::Status.publish('copy_data')
          end
          Mongify::Status.publish('copy_data', :action => 'finish')
        end
      end
      
      # Updates the reference ids in the no sql database
      def update_reference_ids
        self.copy_tables.each do |t|
          rows = no_sql_connection.select_rows(t.name)
          Mongify::Status.publish('update_references', :size => rows.count, :name => "Updating References #{t.name}", :action => 'add')
          rows.each do |row|
            id = row["_id"]
            attributes = fetch_reference_ids(t, row)
            no_sql_connection.update(t.name, id, {"$set" => attributes}) unless attributes.blank?
            Mongify::Status.publish('update_references')
          end
          Mongify::Status.publish('update_references', :action => 'finish')
        end
      end
      
    end
  end
end
