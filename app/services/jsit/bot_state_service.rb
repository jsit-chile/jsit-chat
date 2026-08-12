# Reads whether the bot is on. jWorkflows keeps a Redis key per conversation
# while the bot is on, so that Redis is the source of truth. It is only
# configured in production, so elsewhere (and if it is unreachable) the flag
# mirrored on the conversation is used instead.
class Jsit::BotStateService
  DEFAULT_KEY_TEMPLATE = 'sofia:estado:{account_id}:{conversation_id}'.freeze
  REQUEST_TIMEOUT = 2
  SCAN_BATCH = 500

  def initialize(conversation: nil, account: nil)
    @conversation = conversation
    @account = account || conversation&.account
  end

  def enabled?
    return false if Jsit::BotBlocklist.blocked?(@conversation)

    raw_enabled?
  end

  # display_ids of the account conversations that currently have the bot on
  def enabled_display_ids
    raw_enabled_display_ids - Jsit::BotBlocklist.blocked_display_ids(@account)
  end

  private

  def raw_enabled?
    return mirrored_state if endpoint.blank?

    with_redis { |redis| redis.exists?(key) }
  rescue StandardError => e
    log_failure(e)
    mirrored_state
  end

  def raw_enabled_display_ids
    return mirrored_display_ids if endpoint.blank?

    with_redis { |redis| scan_display_ids(redis) }
  rescue StandardError => e
    log_failure(e)
    mirrored_display_ids
  end

  def scan_display_ids(redis)
    cursor = '0'
    ids = []
    loop do
      cursor, keys = redis.scan(cursor, match: scan_pattern, count: SCAN_BATCH)
      # The key ends with the conversation display_id, e.g. sofia:estado:4:2
      ids.concat(keys.filter_map { |key| key.split(':').last[/\A\d+\z/]&.to_i })
      break if cursor == '0'
    end
    ids.uniq
  end

  def with_redis
    redis = Redis.new(**connection_config)
    yield redis
  ensure
    redis&.close
  end

  def endpoint
    ENV.fetch('REDIS_JWORKFLOWS_ENDPOINT', nil).presence
  end

  def connection_config
    {
      host: endpoint,
      port: ENV.fetch('REDIS_JWORKFLOWS_PORT', 6379).to_i,
      username: ENV.fetch('REDIS_JWORKFLOWS_USER', nil).presence,
      password: ENV.fetch('REDIS_JWORKFLOWS_PASS', nil).presence,
      timeout: REQUEST_TIMEOUT,
      reconnect_attempts: 1
    }.compact
  end

  def template
    ENV.fetch('JWORKFLOWS_BOT_KEY_TEMPLATE', DEFAULT_KEY_TEMPLATE)
  end

  def key
    interpolate(conversation_id: @conversation.display_id.to_s, wa_id: Jsit::WaId.for(@conversation))
  end

  def scan_pattern
    interpolate(conversation_id: '*', wa_id: '*')
  end

  # Placeholders: {wa_id}, {account_id} (or {account}), {conversation_id} (or {conv})
  def interpolate(conversation_id:, wa_id:)
    template.gsub('{wa_id}', wa_id)
            .gsub(/\{account(_id)?\}/, @account.id.to_s)
            .gsub(/\{conv(ersation_id)?\}/, conversation_id)
  end

  def mirrored_state
    @conversation.present? && @conversation.custom_attributes['jsit_bot_enabled'] == true
  end

  def mirrored_display_ids
    @account.conversations.where("custom_attributes->>'jsit_bot_enabled' = 'true'").pluck(:display_id)
  end

  def log_failure(error)
    Rails.logger.error("[JsitBotState] redis read failed: #{error.class}: #{error.message}")
  end
end
