class Api::V1::Accounts::JsitBotStatesController < Api::V1::Accounts::BaseController
  def index
    return head :forbidden unless Current.account.jsit_ai_functions

    service = Jsit::BotStateService.new(account: Current.account)
    render json: {
      default_enabled: Current.account.jsit_bot_default_on,
      exception_conversation_ids: service.exception_display_ids
    }
  end
end
