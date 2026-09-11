# frozen_string_literal: true

class CreateVvBpmnBbo < ActiveRecord::Migration[7.0]
  def change
    create_table :bpmn_bbo_packages do |t|
      t.string :definition_key, null: false
      t.string :name
      t.string :target_namespace
      t.string :ledger_placement, null: false, default: "canonical"
      t.timestamps
    end
    add_index :bpmn_bbo_packages, :definition_key, unique: true
    add_index :bpmn_bbo_packages, :ledger_placement

    create_table :bpmn_bbo_datatypes do |t|
      t.string :kind, null: false
      t.string :name, null: false
      t.string :uri
      t.string :ar_class_name
      t.string :unit_iri
      t.references :parent, foreign_key: { to_table: :bpmn_bbo_datatypes }
      t.boolean :is_collection, null: false, default: false
      t.integer :definition_version_id
      t.text :structure_schema
      t.timestamps
    end
    add_index :bpmn_bbo_datatypes, [:kind, :name], unique: true,
              where: "definition_version_id IS NULL",
              name: "idx_bpmn_bbo_datatypes_catalog"
    add_index :bpmn_bbo_datatypes, [:definition_version_id, :name], unique: true,
              where: "definition_version_id IS NOT NULL",
              name: "idx_bpmn_bbo_datatypes_version"

    create_table :bpmn_bbo_definition_versions do |t|
      t.references :package, null: false, foreign_key: { to_table: :bpmn_bbo_packages }
      t.string :version, null: false
      t.string :source_digest, null: false
      t.string :exporter
      t.datetime :exported_at
      t.boolean :is_latest, null: false, default: false
      t.timestamps
    end
    add_index :bpmn_bbo_definition_versions, [:package_id, :version], unique: true
    add_index :bpmn_bbo_definition_versions, [:package_id, :is_latest]

    add_foreign_key :bpmn_bbo_datatypes, :bpmn_bbo_definition_versions,
                    column: :definition_version_id

    create_table :bpmn_bbo_typed_values do |t|
      t.references :datatype, null: false, foreign_key: { to_table: :bpmn_bbo_datatypes }
      t.text :string_value
      t.integer :integer_value
      t.decimal :decimal_value
      t.boolean :boolean_value
      t.datetime :datetime_value
      t.text :json_value
      t.string :blob_digest
      t.string :record_type
      t.integer :record_id
      t.timestamps
    end
    add_index :bpmn_bbo_typed_values, [:record_type, :record_id]

    create_table :bpmn_bbo_collaborations do |t|
      t.references :definition_version, null: false,
                   foreign_key: { to_table: :bpmn_bbo_definition_versions }
      t.string :element_id, null: false
      t.string :name
      t.timestamps
    end
    add_index :bpmn_bbo_collaborations, [:definition_version_id, :element_id], unique: true,
              name: "idx_bpmn_bbo_collaborations_el"

    create_table :bpmn_bbo_processes do |t|
      t.references :definition_version, null: false,
                   foreign_key: { to_table: :bpmn_bbo_definition_versions }
      t.string :element_id, null: false
      t.string :name
      t.boolean :is_executable, null: false, default: false
      t.string :process_type
      t.boolean :is_closed, null: false, default: false
      t.boolean :callable, null: false, default: false
      t.timestamps
    end
    add_index :bpmn_bbo_processes, [:definition_version_id, :element_id], unique: true,
              name: "idx_bpmn_bbo_processes_el"

    create_table :bpmn_bbo_expressions do |t|
      t.references :definition_version, null: false,
                   foreign_key: { to_table: :bpmn_bbo_definition_versions }
      t.string :element_id
      t.string :kind, null: false
      t.string :language
      t.text :body, null: false
      t.references :evaluates_to, foreign_key: { to_table: :bpmn_bbo_datatypes }
      t.timestamps
    end

    create_table :bpmn_bbo_item_definitions do |t|
      t.references :definition_version, null: false,
                   foreign_key: { to_table: :bpmn_bbo_definition_versions }
      t.string :element_id, null: false
      t.string :item_kind, null: false
      t.references :datatype, null: false, foreign_key: { to_table: :bpmn_bbo_datatypes }
      t.boolean :is_collection, null: false, default: false
      t.timestamps
    end
    add_index :bpmn_bbo_item_definitions, [:definition_version_id, :element_id], unique: true,
              name: "idx_bpmn_bbo_item_defs_el"

    create_table :bpmn_bbo_messages do |t|
      t.references :definition_version, null: false,
                   foreign_key: { to_table: :bpmn_bbo_definition_versions }
      t.string :element_id, null: false
      t.string :name
      t.references :item_definition, foreign_key: { to_table: :bpmn_bbo_item_definitions }
      t.timestamps
    end
    add_index :bpmn_bbo_messages, [:definition_version_id, :element_id], unique: true,
              name: "idx_bpmn_bbo_messages_el"

    create_table :bpmn_bbo_signals do |t|
      t.references :definition_version, null: false,
                   foreign_key: { to_table: :bpmn_bbo_definition_versions }
      t.string :element_id, null: false
      t.string :name
      t.references :structure_datatype, foreign_key: { to_table: :bpmn_bbo_datatypes }
      t.timestamps
    end
    add_index :bpmn_bbo_signals, [:definition_version_id, :element_id], unique: true,
              name: "idx_bpmn_bbo_signals_el"

    create_table :bpmn_bbo_errors do |t|
      t.references :definition_version, null: false,
                   foreign_key: { to_table: :bpmn_bbo_definition_versions }
      t.string :element_id, null: false
      t.string :name
      t.string :error_code
      t.references :structure_datatype, foreign_key: { to_table: :bpmn_bbo_datatypes }
      t.timestamps
    end
    add_index :bpmn_bbo_errors, [:definition_version_id, :element_id], unique: true,
              name: "idx_bpmn_bbo_errors_el"

    create_table :bpmn_bbo_escalations do |t|
      t.references :definition_version, null: false,
                   foreign_key: { to_table: :bpmn_bbo_definition_versions }
      t.string :element_id, null: false
      t.string :name
      t.string :escalation_code
      t.timestamps
    end
    add_index :bpmn_bbo_escalations, [:definition_version_id, :element_id], unique: true,
              name: "idx_bpmn_bbo_escalations_el"

    create_table :bpmn_bbo_loop_characteristics do |t|
      t.string :type, null: false
      t.boolean :is_sequential, null: false, default: true
      t.references :loop_condition, foreign_key: { to_table: :bpmn_bbo_expressions }
      t.integer :loop_maximum
      t.boolean :test_before
      t.references :loop_cardinality, foreign_key: { to_table: :bpmn_bbo_expressions }
      t.references :completion_condition, foreign_key: { to_table: :bpmn_bbo_expressions }
      t.integer :collection_item_aware_id
      t.timestamps
    end

    create_table :bpmn_bbo_flow_nodes do |t|
      t.string :type, null: false
      t.references :process, null: false, foreign_key: { to_table: :bpmn_bbo_processes }
      t.string :element_id, null: false
      t.string :name
      t.integer :default_flow_id
      t.string :called_definition_key
      t.references :called_process, foreign_key: { to_table: :bpmn_bbo_processes }
      t.references :loop_characteristics, foreign_key: { to_table: :bpmn_bbo_loop_characteristics }
      t.references :attached_to, foreign_key: { to_table: :bpmn_bbo_flow_nodes }
      t.references :container_node, foreign_key: { to_table: :bpmn_bbo_flow_nodes }
      t.boolean :cancel_activity
      t.string :event_gateway_type
      t.string :gateway_direction
      t.timestamps
    end
    add_index :bpmn_bbo_flow_nodes, [:process_id, :element_id], unique: true
    add_index :bpmn_bbo_flow_nodes, :type

    create_table :bpmn_bbo_sequence_flows do |t|
      t.references :process, null: false, foreign_key: { to_table: :bpmn_bbo_processes }
      t.string :element_id, null: false
      t.string :name
      t.references :source, null: false, foreign_key: { to_table: :bpmn_bbo_flow_nodes }
      t.references :target, null: false, foreign_key: { to_table: :bpmn_bbo_flow_nodes }
      t.references :condition_expression, foreign_key: { to_table: :bpmn_bbo_expressions }
      t.boolean :is_immediate
      t.timestamps
    end
    add_index :bpmn_bbo_sequence_flows, [:process_id, :element_id], unique: true,
              name: "idx_bpmn_bbo_seq_flows_el"

    add_foreign_key :bpmn_bbo_flow_nodes, :bpmn_bbo_sequence_flows, column: :default_flow_id

    create_table :bpmn_bbo_event_definitions do |t|
      t.string :type, null: false
      t.references :event, null: false, foreign_key: { to_table: :bpmn_bbo_flow_nodes }
      t.references :message, foreign_key: { to_table: :bpmn_bbo_messages }
      t.references :signal, foreign_key: { to_table: :bpmn_bbo_signals }
      t.references :error, foreign_key: { to_table: :bpmn_bbo_errors }
      t.references :escalation, foreign_key: { to_table: :bpmn_bbo_escalations }
      t.string :time_cycle
      t.string :time_date
      t.string :time_duration
      t.references :condition_expression, foreign_key: { to_table: :bpmn_bbo_expressions }
      t.references :activity_ref, foreign_key: { to_table: :bpmn_bbo_flow_nodes }
      t.timestamps
    end

    create_table :bpmn_bbo_item_aware_elements do |t|
      t.string :type, null: false
      t.references :process, null: false, foreign_key: { to_table: :bpmn_bbo_processes }
      t.string :element_id, null: false
      t.string :name
      t.references :item_definition, foreign_key: { to_table: :bpmn_bbo_item_definitions }
      t.string :data_state
      t.boolean :is_collection, null: false, default: false
      t.references :default_value, foreign_key: { to_table: :bpmn_bbo_typed_values }
      t.timestamps
    end
    add_index :bpmn_bbo_item_aware_elements, [:process_id, :element_id], unique: true,
              name: "idx_bpmn_bbo_iae_el"

    add_foreign_key :bpmn_bbo_loop_characteristics, :bpmn_bbo_item_aware_elements,
                    column: :collection_item_aware_id

    create_table :bpmn_bbo_data_associations do |t|
      t.references :process, null: false, foreign_key: { to_table: :bpmn_bbo_processes }
      t.string :element_id, null: false
      t.string :kind, null: false
      t.references :source_element, foreign_key: { to_table: :bpmn_bbo_item_aware_elements }
      t.references :target_element, foreign_key: { to_table: :bpmn_bbo_item_aware_elements }
      t.references :transformation_expression, foreign_key: { to_table: :bpmn_bbo_expressions }
      t.timestamps
    end

    create_table :bpmn_bbo_lane_sets do |t|
      t.references :process, null: false, foreign_key: { to_table: :bpmn_bbo_processes }
      t.string :element_id, null: false
      t.string :name
      t.timestamps
    end

    create_table :bpmn_bbo_lanes do |t|
      t.references :lane_set, null: false, foreign_key: { to_table: :bpmn_bbo_lane_sets }
      t.references :process, null: false, foreign_key: { to_table: :bpmn_bbo_processes }
      t.string :element_id, null: false
      t.string :name
      t.references :parent_lane, foreign_key: { to_table: :bpmn_bbo_lanes }
      t.timestamps
    end

    create_table :bpmn_bbo_lane_flow_nodes do |t|
      t.references :lane, null: false, foreign_key: { to_table: :bpmn_bbo_lanes }
      t.references :flow_node, null: false, foreign_key: { to_table: :bpmn_bbo_flow_nodes }
      t.integer :position
      t.timestamps
    end
    add_index :bpmn_bbo_lane_flow_nodes, [:lane_id, :flow_node_id], unique: true,
              name: "idx_bpmn_bbo_lane_nodes"

    create_table :bpmn_bbo_org_jobs do |t|
      t.string :name, null: false
      t.string :key, null: false
      t.timestamps
    end
    add_index :bpmn_bbo_org_jobs, :key, unique: true

    create_table :bpmn_bbo_org_roles do |t|
      t.string :name, null: false
      t.string :key, null: false
      t.timestamps
    end
    add_index :bpmn_bbo_org_roles, :key, unique: true

    create_table :bpmn_bbo_org_agents do |t|
      t.string :kind, null: false
      t.string :name
      t.integer :actor_id
      t.timestamps
    end
    add_index :bpmn_bbo_org_agents, :actor_id

    create_table :bpmn_bbo_resource_roles do |t|
      t.references :flow_node, null: false, foreign_key: { to_table: :bpmn_bbo_flow_nodes }
      t.string :kind, null: false
      t.references :agent, foreign_key: { to_table: :bpmn_bbo_org_agents }
      t.references :org_role, foreign_key: { to_table: :bpmn_bbo_org_roles }
      t.references :org_job, foreign_key: { to_table: :bpmn_bbo_org_jobs }
      t.references :assignment_expression, foreign_key: { to_table: :bpmn_bbo_expressions }
      t.timestamps
    end

    create_table :bpmn_bbo_documentations do |t|
      t.string :subject_type, null: false
      t.integer :subject_id, null: false
      t.text :text, null: false
      t.string :text_format, default: "text/plain"
      t.timestamps
    end
    add_index :bpmn_bbo_documentations, [:subject_type, :subject_id]

    create_table :bpmn_bbo_extension_values do |t|
      t.string :owner_type, null: false
      t.integer :owner_id, null: false
      t.string :namespace, null: false
      t.string :local_name, null: false
      t.references :value, foreign_key: { to_table: :bpmn_bbo_typed_values }
      t.timestamps
    end
    add_index :bpmn_bbo_extension_values, [:owner_type, :owner_id]

    create_table :bpmn_bbo_participants do |t|
      t.references :collaboration, null: false, foreign_key: { to_table: :bpmn_bbo_collaborations }
      t.string :element_id, null: false
      t.string :name
      t.references :process, foreign_key: { to_table: :bpmn_bbo_processes }
      t.timestamps
    end
    add_index :bpmn_bbo_participants, [:collaboration_id, :element_id], unique: true,
              name: "idx_bpmn_bbo_participants_el"

    create_table :bpmn_bbo_message_flows do |t|
      t.references :collaboration, null: false, foreign_key: { to_table: :bpmn_bbo_collaborations }
      t.string :element_id, null: false
      t.references :source_participant, foreign_key: { to_table: :bpmn_bbo_participants }
      t.references :target_participant, foreign_key: { to_table: :bpmn_bbo_participants }
      t.references :source_node, foreign_key: { to_table: :bpmn_bbo_flow_nodes }
      t.references :target_node, foreign_key: { to_table: :bpmn_bbo_flow_nodes }
      t.references :message, foreign_key: { to_table: :bpmn_bbo_messages }
      t.timestamps
    end

    create_table :bpmn_bbo_run_process_instances do |t|
      t.references :process, null: false, foreign_key: { to_table: :bpmn_bbo_processes }
      t.references :parent, foreign_key: { to_table: :bpmn_bbo_run_process_instances }
      t.string :business_key
      t.string :state, null: false
      t.datetime :started_at
      t.datetime :ended_at
      t.references :start_user_agent, foreign_key: { to_table: :bpmn_bbo_org_agents }
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end
    add_index :bpmn_bbo_run_process_instances, [:process_id, :state]
    add_index :bpmn_bbo_run_process_instances, :business_key

    create_table :bpmn_bbo_run_activity_instances do |t|
      t.references :process_instance, null: false,
                   foreign_key: { to_table: :bpmn_bbo_run_process_instances }
      t.references :flow_node, null: false, foreign_key: { to_table: :bpmn_bbo_flow_nodes }
      t.references :parent, foreign_key: { to_table: :bpmn_bbo_run_activity_instances }
      t.string :state
      t.datetime :started_at
      t.datetime :ended_at
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end

    create_table :bpmn_bbo_run_jobs do |t|
      t.references :process_instance, null: false,
                   foreign_key: { to_table: :bpmn_bbo_run_process_instances }
      t.references :activity_instance, null: false,
                   foreign_key: { to_table: :bpmn_bbo_run_activity_instances }
      t.references :flow_node, null: false, foreign_key: { to_table: :bpmn_bbo_flow_nodes }
      t.string :kind, null: false
      t.string :state, null: false
      t.references :assignee_agent, foreign_key: { to_table: :bpmn_bbo_org_agents }
      t.datetime :due_at
      t.integer :retries, null: false, default: 0
      t.datetime :claimed_at
      t.string :claimed_by
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end

    create_table :bpmn_bbo_run_variables do |t|
      t.references :process_instance, null: false,
                   foreign_key: { to_table: :bpmn_bbo_run_process_instances }
      t.references :activity_instance, foreign_key: { to_table: :bpmn_bbo_run_activity_instances }
      t.string :name, null: false
      t.references :item_definition, foreign_key: { to_table: :bpmn_bbo_item_definitions }
      t.references :value, null: false, foreign_key: { to_table: :bpmn_bbo_typed_values }
      t.string :scope_key, null: false
      t.timestamps
    end
    add_index :bpmn_bbo_run_variables, :scope_key, unique: true

    create_table :bpmn_bbo_run_incidents do |t|
      t.references :job, null: false, foreign_key: { to_table: :bpmn_bbo_run_jobs }
      t.string :kind, null: false
      t.text :message
      t.datetime :resolved_at
      t.timestamps
    end

    create_table :bpmn_bbo_run_event_subscriptions do |t|
      t.references :process_instance, null: false,
                   foreign_key: { to_table: :bpmn_bbo_run_process_instances }
      t.references :activity_instance, foreign_key: { to_table: :bpmn_bbo_run_activity_instances }
      t.string :kind, null: false
      t.string :name
      t.datetime :due_at
      t.timestamps
    end

    reversible do |dir|
      dir.up { execute <<~SQL }
        CREATE TRIGGER bpmn_bbo_typed_values_ar_class_insert
        BEFORE INSERT ON bpmn_bbo_typed_values
        FOR EACH ROW
        WHEN (SELECT kind FROM bpmn_bbo_datatypes WHERE id = NEW.datatype_id) = 'ar_class'
          AND (NEW.record_type IS NULL OR NEW.record_id IS NULL
               OR NEW.string_value IS NOT NULL OR NEW.integer_value IS NOT NULL
               OR NEW.decimal_value IS NOT NULL OR NEW.boolean_value IS NOT NULL
               OR NEW.datetime_value IS NOT NULL OR NEW.json_value IS NOT NULL)
        BEGIN
          SELECT RAISE(ABORT, 'ar_class_payload_mismatch');
        END;
      SQL
      dir.up { execute <<~SQL }
        CREATE TRIGGER bpmn_bbo_typed_values_ar_class_update
        BEFORE UPDATE ON bpmn_bbo_typed_values
        FOR EACH ROW
        WHEN (SELECT kind FROM bpmn_bbo_datatypes WHERE id = NEW.datatype_id) = 'ar_class'
          AND (NEW.record_type IS NULL OR NEW.record_id IS NULL
               OR NEW.string_value IS NOT NULL OR NEW.integer_value IS NOT NULL
               OR NEW.decimal_value IS NOT NULL OR NEW.boolean_value IS NOT NULL
               OR NEW.datetime_value IS NOT NULL OR NEW.json_value IS NOT NULL)
        BEGIN
          SELECT RAISE(ABORT, 'ar_class_payload_mismatch');
        END;
      SQL
      dir.down do
        execute "DROP TRIGGER IF EXISTS bpmn_bbo_typed_values_ar_class_insert;"
        execute "DROP TRIGGER IF EXISTS bpmn_bbo_typed_values_ar_class_update;"
      end
    end
  end
end
