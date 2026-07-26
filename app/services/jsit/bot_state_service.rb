# Reads whether the bot is on for a conversation. jWorkflows keeps a Redis key
# per contact while the bot is on, so that Redis is the source of truth. It is
# only configured in production, so elsewhere (and if it is unreachable) the
# flag mirrored on the conversation is used instead.
class Jsit::BotStateService
  DEFAULT_KEY_TEMPLATE = 'sofia:estado:{account_id}:{conversation_id}'.freeze
  REQUEST_TIMEOUT = 2

  def initialize(conversation:)
    @conversation = conversation
  end

  def enabled?
    return mirrored_state if endpoint.blank?

    redis = Redis.new(**connection_config)
    begin
      redis.exists?(key)
    ensure
      redis.close
    end
  rescue StandardError => e
    Rails.logger.error("[JsitBotState] redis read failed: #{e.class}: #{e.message}")
    mirrored_state
  end

  private

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

  # Template placeholders: {wa_id}, {account_id} (or {account}), {conversation_id} (or {conv})
  def key
    ENV.fetch('JWORKFLOWS_BOT_KEY_TEMPLATE', DEFAULT_KEY_TEMPLATE)
       .gsub('{wa_id}', Jsit::WaId.for(@conversation))
       .gsub(/\{account(_id)?\}/, @conversation.account_id.to_s)
       .gsub(/\{conv(ersation_id)?\}/, @conversation.display_id.to_s)
  end

  def mirrored_state
    @conversation.custom_attributes['jsit_bot_enabled'] == true
  end
end
