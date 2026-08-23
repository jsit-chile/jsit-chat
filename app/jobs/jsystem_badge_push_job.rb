# Pushes the "pending attention" conversation count for a single account to jSystem,
# which renders it as a notification badge. Triggered from conversation/message events
# for near real-time updates, with a cron run as a robust backup.
#
# The payload is only sent when it differs from the last one jSystem acknowledged, so
# an idle account generates no traffic beyond the heartbeat (see HEARTBEAT_TTL).
class JsystemBadgePushJob < ApplicationJob
  queue_as :low

  # Chatwoot account whose badge is mirrored into jSystem.
  ACCOUNT_ID = 2
  DEFAULT_URL = 'https://api.system.jsit.cl/api/chat/badge'.freeze
  REQUEST_TIMEOUT = 5
  # jSystem stores the breakdown as an opaque JSON blob, so the ID list rides
  # along without schema changes on its side; cap it to keep the payload small.
  MAX_CONVERSATION_IDS = 50
  # How long a pushed payload keeps suppressing identical ones. When it expires the
  # next run pushes again, so jSystem recovers on its own after losing its state.
  HEARTBEAT_TTL = 5.minutes
  # Lets a burst of events settle so the job reads the state once, already stable.
  DEBOUNCE_WINDOW = 5.seconds
  # Only a guard for a claimed job that never runs; the job releases its claim itself.
  IN_FLIGHT_TTL = 2.minutes

  # Collapses bursts: at most one push per account is queued at a time. Same claim
  # pattern as AutoAssignment::AssignmentJob.enqueue_for_inbox, token included so a
  # job only releases its own claim.
  def self.enqueue_coalesced(account_id = ACCOUNT_ID)
    key = format(::Redis::Alfred::JSYSTEM_BADGE_IN_FLIGHT, account_id: account_id)
    token = SecureRandom.uuid
    return false unless ::Redis::Alfred.set(key, token, nx: true, ex: IN_FLIGHT_TTL)
    return true if set(wait: DEBOUNCE_WINDOW).perform_later(account_id, token: token)

    # Enqueue was halted; release our own claim so the badge isn't gated until the TTL.
    ::Redis::Alfred.delete_if_equals(key, token)
    false
  rescue StandardError
    ::Redis::Alfred.delete_if_equals(key, token)
    raise
  end

  def perform(account_id = ACCOUNT_ID, token: nil)
    release_in_flight(account_id, token)

    secret = ENV.fetch('JSYSTEM_BADGE_SECRET', nil)
    return if secret.blank?

    account = Account.find_by(id: account_id)
    return unless account

    body = payload(account.id, compute_metrics(account))
    push(account.id, body, secret) unless unchanged?(account.id, body)
  end

  private

  # Released on entry rather than after the push: the blind window is then just the
  # debounce, during which this job has not read the counts yet, so any event
  # suppressed meanwhile is still reflected in what it is about to send.
  def release_in_flight(account_id, token)
    return if token.blank?

    ::Redis::Alfred.delete_if_equals(format(::Redis::Alfred::JSYSTEM_BADGE_IN_FLIGHT, account_id: account_id), token)
  rescue StandardError
    nil
  end

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

  def payload(account_id, metrics)
    { count: metrics[:count], account_id: account_id, breakdown: metrics[:breakdown] }
  end

  # The whole payload is compared, not just the count: reading one conversation while
  # another one comes in leaves the count untouched but changes the linked ids.
  def unchanged?(account_id, body)
    ::Redis::Alfred.get(last_push_key(account_id)) == digest(body)
  rescue StandardError => e
    # Redis being down must not switch the badge off: fall back to always pushing.
    Rails.logger.warn("[JsystemBadgePush] dedup unavailable: #{e.class}")
    false
  end

  def push(account_id, body, secret)
    response = HTTParty.post(
      ENV.fetch('JSYSTEM_BADGE_URL', DEFAULT_URL),
      headers: { 'Content-Type' => 'application/json', 'X-Chat-Secret' => secret },
      body: body.to_json,
      timeout: REQUEST_TIMEOUT
    )

    # Only a 200 means jSystem holds this payload; anything else must be retried.
    remember(account_id, body) if response.code == 200
    log_response(response.code, body)
  rescue StandardError => e
    # jSystem being unreachable must never break Chatwoot; just log and move on.
    Rails.logger.error("[JsystemBadgePush] push failed: #{e.class}: #{e.message}")
  end

  def remember(account_id, body)
    ::Redis::Alfred.set(last_push_key(account_id), digest(body), ex: HEARTBEAT_TTL)
  rescue StandardError
    # Without the marker we push more often, never less.
    nil
  end

  def digest(body)
    Digest::MD5.hexdigest(body.to_json)
  end

  def last_push_key(account_id)
    format(::Redis::Alfred::JSYSTEM_BADGE_LAST_PUSH, account_id: account_id)
  end

  def log_response(code, body)
    breakdown = body[:breakdown]
    case code
    when 200
      Rails.logger.info("[JsystemBadgePush] pushed count=#{body[:count]} unassigned=#{breakdown[:unassigned]} " \
                        "open=#{breakdown[:open]} ids=#{breakdown[:conversation_ids].size}")
    when 401
      Rails.logger.error('[JsystemBadgePush] unauthorized (401): check JSYSTEM_BADGE_SECRET')
    else
      Rails.logger.error("[JsystemBadgePush] unexpected response status=#{code}")
    end
  end
end
