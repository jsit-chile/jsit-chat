# Triggers a near real-time jSystem badge push whenever conversation state that can
# affect the "pending attention" count changes. The cron job remains the robust backup.
#
# conversation_updated is deliberately not handled: of the attributes that fire it,
# status and assignee already have their own event here, and the rest (labels,
# priority, custom attributes, team) never move the badge.
class JsystemBadgeListener < BaseListener
  def conversation_created(event)
    trigger_for_conversation(event)
  end

  def conversation_status_changed(event)
    trigger_for_conversation(event)
  end

  def assignee_changed(event)
    trigger_for_conversation(event)
  end

  # Only incoming messages move the count, and this account is a bot that answers
  # on its own, so outgoing/activity/template messages would be pure noise.
  def message_created(event)
    message, account = extract_message_and_account(event)
    return unless message.incoming?

    enqueue(account)
  end

  private

  def trigger_for_conversation(event)
    _conversation, account = extract_conversation_and_account(event)
    enqueue(account)
  end

  def enqueue(account)
    return unless account&.id == JsystemBadgePushJob::ACCOUNT_ID

    JsystemBadgePushJob.enqueue_coalesced
  end
end
