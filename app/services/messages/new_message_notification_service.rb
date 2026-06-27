class Messages::NewMessageNotificationService
  pattr_initialize [:message!]

  def perform
    return unless message.notifiable?

    notify_conversation_assignee
    notify_participating_users
    notify_inbox_members
  end

  private

  delegate :conversation, :sender, :account, to: :message

  def notify_conversation_assignee
    return if conversation.assignee.blank?
    return if already_notified?(conversation.assignee)
    return if conversation.assignee == sender

    NotificationBuilder.new(
      notification_type: 'assigned_conversation_new_message',
      user: conversation.assignee,
      account: account,
      primary_actor: message.conversation,
      secondary_actor: message
    ).perform
  end

  def notify_participating_users
    participating_users = conversation.conversation_participants.map(&:user)
    participating_users -= [sender] if sender.is_a?(User)

    participating_users.uniq.each do |participant|
      next if already_notified?(participant)

      NotificationBuilder.new(
        notification_type: 'participating_conversation_new_message',
        user: participant,
        account: account,
        primary_actor: message.conversation,
        secondary_actor: message
      ).perform
    end
  end

  # Notify every inbox member on each new message so supervisors following the
  # inbox (e.g. AI-secretary workflows) get notified regardless of the assignee.
  # Push/email delivery still respects each user's notification settings.
  def notify_inbox_members
    inbox_members = conversation.inbox.members.to_a
    inbox_members -= [sender] if sender.is_a?(User)

    inbox_members.uniq.each do |member|
      next if already_notified?(member)

      NotificationBuilder.new(
        notification_type: 'participating_conversation_new_message',
        user: member,
        account: account,
        primary_actor: message.conversation,
        secondary_actor: message
      ).perform
    end
  end

  # The user could already have been notified via a mention or via assignment
  # So we don't need to notify them again
  def already_notified?(user)
    conversation.notifications.exists?(user: user, secondary_actor: message)
  end
end
