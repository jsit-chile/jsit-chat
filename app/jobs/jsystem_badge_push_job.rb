# Pushes the "pending attention" conversation count for a single account to jSystem,
# which renders it as a notification badge. Runs on a cron cadence as a robust backup
# and is also triggered from conversation/message events for near real-time updates.
class JsystemBadgePushJob < ApplicationJob
  queue_as :low

  # Chatwoot account whose badge is mirrored into jSystem.
  ACCOUNT_ID = 2
  DEFAULT_URL = 'https://api.system.jsit.cl/api/chat/badge'.freeze
  REQUEST_TIMEOUT = 5

  def perform(account_id = ACCOUNT_ID)
    account = Account.find_by(id: account_id)
    return unless account

    push(account.id, compute_metrics(account))
  end

  private

  # jSystem stores the breakdown as an opaque JSON blob, so the ID list rides
  # along without schema changes on its side; cap it to keep the payload small.
  MAX_CONVERSATION_IDS = 50

  # The badge counts the conversations the dashboard shows as unread (open, with
  # unread incoming messages). The breakdown carries the other buckets plus the
  # display_ids of the unread conversations so jSystem can link to each one.
  def compute_metrics(account)
    unread_ids = account.conversations.open.with_unread_incoming_messages
                        .order(:display_id).pluck(:display_id)

    {
      count: unread_ids.size,
      breakdown: {
        unassigned: account.conversations.open.unassigned.count,
        unread: unread_ids.size,
        open: account.conversations.open.count,
        conversation_ids: unread_ids.first(MAX_CONVERSATION_IDS)
      }
    }
  end

  def push(account_id, metrics)
    secret = ENV.fetch('JSYSTEM_BADGE_SECRET', nil)
    return if secret.blank?

    body = { count: metrics[:count], account_id: account_id, breakdown: metrics[:breakdown] }

    response = HTTParty.post(
      ENV.fetch('JSYSTEM_BADGE_URL', DEFAULT_URL),
      headers: { 'Content-Type' => 'application/json', 'X-Chat-Secret' => secret },
      body: body.to_json,
      timeout: REQUEST_TIMEOUT
    )

    log_response(response.code, metrics)
  rescue StandardError => e
    # jSystem being unreachable must never break Chatwoot; just log and move on.
    Rails.logger.error("[JsystemBadgePush] push failed: #{e.class}: #{e.message}")
  end

  def log_response(code, metrics)
    case code
    when 200
      Rails.logger.info("[JsystemBadgePush] badge pushed (count=#{metrics[:count]} breakdown=#{metrics[:breakdown]})")
    when 401
      Rails.logger.error('[JsystemBadgePush] unauthorized (401): check JSYSTEM_BADGE_SECRET')
    else
      Rails.logger.error("[JsystemBadgePush] unexpected response status=#{code}")
    end
  end
end
