class SimplifyModelParameters < ActiveRecord::Migration[7.1]
  def up
    remove_index :model_parameters, name: "uq_model_parameters"
    remove_column :model_parameters, :model_kind, :string
    remove_column :model_parameters, :mse_resid,  :float

    # Eliminar duplicados conservando solo el registro de menor id por par
    execute <<~SQL
      DELETE FROM model_parameters
      WHERE id NOT IN (
        SELECT MIN(id)
        FROM model_parameters
        GROUP BY municipality_code, agent_type_code
      )
    SQL

    add_index :model_parameters, [:municipality_code, :agent_type_code],
              unique: true, name: "uq_model_parameters"
  end

  def down
    remove_index :model_parameters, name: "uq_model_parameters"
    add_column :model_parameters, :model_kind, :string
    add_column :model_parameters, :mse_resid,  :float
    add_index :model_parameters, [:municipality_code, :agent_type_code, :model_kind],
              unique: true, name: "uq_model_parameters"
  end
end
