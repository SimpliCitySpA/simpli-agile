class CreateModelParameters < ActiveRecord::Migration[7.1]
  def change
    create_table :model_parameters do |t|
      t.integer :municipality_code, null: false
      t.string  :agent_type_code,   null: false
      t.string  :model_kind,        null: false   # 'mnl_choice' | 'hedonic_price'
      t.jsonb   :variables,         default: []
      t.jsonb   :coefficients,      default: {}
      t.float   :mse_resid                        # solo para hedonic_price
      t.timestamps default: -> { "CURRENT_TIMESTAMP" }
    end

    add_index :model_parameters, [:municipality_code, :agent_type_code, :model_kind],
              unique: true, name: "uq_model_parameters"

    add_foreign_key :model_parameters, :municipalities, column: :municipality_code, primary_key: :municipality_code
  end
end
