# Triggers a near real-time jSystem badge push whenever conversation state that can
# affect the "pending attention" count changes. The cron job remains the robust backup.
class JsystemBadgeListener < BaseListener
  def conversation_created(event)
    trigger_for_conversation(event)
  end

  def conversation_status_changed(event)
    trigger_for_conversation(event)
  end

  def conversation_updated(event)
    trigger_for_conversation(event)
  end

  def assignee_changed(event)
    trigger_for_conversation(event)
  end

  def message_created(event)
    _message, account = extract_message_and_account(event)
    enqueue(account)
  end

  private

  def trigger_for_conversation(event)
    _conversation, account = extract_conversation_and_account(event)
    enqueue(account)
  end

  def enqueue(account)
    return unless account&.id == JsystemBadgePushJob::ACCOUNT_ID

    JsystemBadgePushJob.perform_later
  end
end
