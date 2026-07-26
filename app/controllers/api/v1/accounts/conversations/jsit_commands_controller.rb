class Api::V1::Accounts::Conversations::JsitCommandsController < Api::V1::Accounts::Conversations::BaseController
  def create
    sent = Jsit::ComandoService.new(conversation: @conversation, comando: params[:comando]).perform
    head(sent ? :ok : :bad_gateway)
  end
end
