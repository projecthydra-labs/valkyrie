# frozen_string_literal: true
class CreateOrmResources < ActiveRecord::Migration[5.0]
  def change
    options = if ENV["VALKYRIE_ID_TYPE"] == "string"
      { id: :text, default: -> { '(uuid_generate_v4())::text' } }
    else
      { id: :uuid }
    end
    create_table :orm_resources, **options do |t|
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end
    add_index :orm_resources, :metadata, using: :gin
  end
end
