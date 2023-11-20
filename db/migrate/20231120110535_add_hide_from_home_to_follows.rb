# frozen_string_literal: true

require Rails.root.join('lib', 'mastodon', 'migration_helpers')

class AddHideFromHomeToFollows < ActiveRecord::Migration[7.1]
  include Mastodon::MigrationHelpers

  disable_ddl_transaction!

  def up
    safety_assured do
      add_column_with_default :follow_requests, :hide_from_home, :boolean, default: false, allow_null: false
      add_column_with_default :follows, :hide_from_home, :boolean, default: false, allow_null: false
    end
  end

  def down
    remove_column :follows, :hide_from_home
    remove_column :follow_requests, :hide_from_home
  end
end
