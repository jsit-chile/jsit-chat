class Api::V1::Accounts::JsitBotStatesController < Api::V1::Accounts::BaseController
  def index
    render json: { enabled_conversation_ids: Jsit::BotStateService.new(account: Current.account).enabled_display_ids }
  end
end
