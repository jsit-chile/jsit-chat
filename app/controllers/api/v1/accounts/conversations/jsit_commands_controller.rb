class Api::V1::Accounts::Conversations::JsitCommandsController < Api::V1::Accounts::Conversations::BaseController
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

  # update_columns skips the callbacks, so flipping the flag doesn't fire a
  # conversation_updated webhook back into jWorkflows on every toggle.
  def persist_bot_state
    return unless %w[on off].include?(params[:comando])

    @conversation.update_columns( # rubocop:disable Rails/SkipsModelValidations
      custom_attributes: @conversation.custom_attributes.merge('jsit_bot_enabled' => params[:comando] == 'on')
    )
  end
end
