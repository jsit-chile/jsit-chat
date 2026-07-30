class Api::V1::Accounts::JsitBotStatesController < Api::V1::Accounts::BaseController
  def index
    return head :forbidden unless Current.account.jsit_ai_functions

    render json: { enabled_conversation_ids: Jsit::BotStateService.new(account: Current.account).enabled_display_ids }
  end
end
