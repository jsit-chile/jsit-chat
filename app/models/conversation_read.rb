# == Schema Information
#
# Table name: conversation_reads
#
#  id              :bigint           not null, primary key
#  last_seen_at    :datetime
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  conversation_id :bigint           not null
#  user_id         :bigint           not null
#
# Indexes
#
#  index_conversation_reads_on_conversation_id_and_user_id  (conversation_id,user_id) UNIQUE
#  index_conversation_reads_on_user_id                      (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (conversation_id => conversations.id) ON DELETE => cascade
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#
# Per-agent read state of a conversation. Unlike conversations.agent_last_seen_at,
# which any agent overwrites for everyone, each user keeps their own last_seen_at.
class ConversationRead < ApplicationRecord
  belongs_to :conversation
  belongs_to :user
end
