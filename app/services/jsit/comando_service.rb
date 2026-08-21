# Bridges the conversation header bot controls to the JSIT automation workflow.
# The shared secret lives only on the server, so the dashboard posts here and
# this service forwards the command to n8n.
class Jsit::ComandoService
  DEFAULT_URL = 'https://workflows.jsit.cl/webhook/jchat-comando'.freeze
  REQUEST_TIMEOUT = 20
  COMANDOS = %w[on off respond].freeze

  def initialize(conversation:, comando:)
    @conversation = conversation
    @comando = comando.to_s
  end

  def perform
    return false unless COMANDOS.include?(@comando)

    response = HTTParty.post(
      workflow_url,
      headers: { 'Content-Type' => 'application/json', 'X-JSIT-Secret' => ENV.fetch('JSIT_COMANDO_SECRET', '') },
      body: payload.to_json,
      timeout: REQUEST_TIMEOUT
    )

    log_response(response.code)
    response.success?
  rescue StandardError => e
    Rails.logger.error("[JsitComando] #{@comando} failed: #{e.class}: #{e.message}")
    false
  end

  private

  # Each account has its own workflow in jWorkflows, and n8n cannot register the
  # same webhook path twice, so the URL can be overridden per account.
  def workflow_url
    ENV.fetch("JSIT_COMANDO_URL_#{@conversation.account_id}", nil).presence ||
      ENV.fetch('JSIT_COMANDO_URL', DEFAULT_URL)
  end

  def payload
    {
      comando: @comando,
      account_id: @conversation.account_id,
      conversation_id: @conversation.display_id,
      wa_id: Jsit::WaId.for(@conversation)
    }
  end

  def log_response(code)
    if code == 200
      Rails.logger.info("[JsitComando] #{@comando} sent (conversation=#{@conversation.display_id})")
    else
      Rails.logger.error("[JsitComando] #{@comando} rejected status=#{code} (conversation=#{@conversation.display_id})")
    end
  end
end
