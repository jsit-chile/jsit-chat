class CreateConversationReads < ActiveRecord::Migration[7.1]
  def up
    create_table :conversation_reads do |t|
      t.references :conversation, null: false, index: false, foreign_key: { on_delete: :cascade }
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.datetime :last_seen_at
      t.timestamps
    end
    add_index :conversation_reads, [:conversation_id, :user_id], unique: true

    # Start every agent from the shared read state so nothing flips to unread on deploy.
    # Epoch sentinels (agent_last_seen_at < created_at) are corrupt data, left as never seen.
    execute <<~SQL.squish
      INSERT INTO conversation_reads (conversation_id, user_id, last_seen_at, created_at, updated_at)
      SELECT conversations.id, account_users.user_id, conversations.agent_last_seen_at, NOW(), NOW()
      FROM conversations
      INNER JOIN account_users ON account_users.account_id = conversations.account_id
      WHERE conversations.agent_last_seen_at >= conversations.created_at
    SQL
  end

  def down
    drop_table :conversation_reads
  end
end
