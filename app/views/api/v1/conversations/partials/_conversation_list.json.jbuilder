json.id conversation.display_id
json.uuid conversation.uuid
json.account_id conversation.account_id
json.inbox_id conversation.inbox_id
json.status conversation.status

json.meta do
  json.sender do
    json.id conversation.contact.id
    json.name conversation.contact.name
    json.email conversation.contact.email
    json.phone_number conversation.contact.phone_number
    json.thumbnail conversation.contact.avatar_url
  end
  json.channel conversation.inbox.try(:channel_type)

  if conversation.assigned_entity.is_a?(AgentBot)
    json.assignee do
      json.id conversation.assigned_entity.id
      json.name conversation.assigned_entity.name
      json.avatar_url conversation.assigned_entity.avatar_url
    end
    json.assignee_type 'AgentBot'
  elsif conversation.assigned_entity&.account
    json.assignee do
      json.id conversation.assigned_entity.id
      json.name conversation.assigned_entity.name
      json.avatar_url conversation.assigned_entity.avatar_url
    end
    json.assignee_type 'User'
  end
end

json.messages do
  last_msg = conversation.messages.max_by(&:created_at)
  if last_msg.present?
    json.array! [last_msg] do |msg|
      json.id msg.id
      json.content msg.content
      json.message_type msg.message_type
      json.created_at msg.created_at.to_i
      json.sender_type msg.sender_type
      json.sender_id msg.sender_id
    end
  else
    json.array! []
  end
end

json.timestamp conversation.last_activity_at.to_i
json.last_activity_at conversation.last_activity_at.to_i
json.created_at conversation.created_at.to_i
json.can_reply conversation.can_reply?
json.snoozed_until conversation.snoozed_until
json.priority conversation.priority
json.muted conversation.muted?
