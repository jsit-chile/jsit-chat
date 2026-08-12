class Api::V1::Accounts::Conversations::JsitCommandsController < Api::V1::Accounts::Conversations::BaseController
  before_action :ensure_ai_functions_enabled
  before_action :ensure_number_not_blocked, only: :create

  def show
    render json: { bot_enabled: Jsit::BotStateService.new(conversation: @conversation).enabled? }
  end

  def create
    sent = Jsit::ComandoService.new(conversation: @conversation, comando: params[:comando]).perform
    return head :bad_gateway unless sent

    persist_bot_state
    head :ok
  end

  private

  def ensure_ai_functions_enabled
    head :forbidden unless Current.account.jsit_ai_functions
  end

  # Turning the bot on for Sofia's own number loops the assistant answering itself.
  def ensure_number_not_blocked
    return unless params[:comando] == 'on'

    head :forbidden if Jsit::BotBlocklist.blocked?(@conversation)
  end

  # update_columns skips the callbacks, so flipping the flag doesn't fire a
  # conversation_updated webhook back into jWorkflows on every toggle.
  def persist_bot_state
    return unless %w[on off].include?(params[:comando])

    @conversation.update_columns( # rubocop:disable Rails/SkipsModelValidations
      custom_attributes: @conversation.custom_attributes.merge('jsit_bot_enabled' => params[:comando] == 'on')
    )
  end
end
