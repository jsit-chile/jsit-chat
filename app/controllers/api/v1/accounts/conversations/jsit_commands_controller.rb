class Api::V1::Accounts::Conversations::JsitCommandsController < Api::V1::Accounts::Conversations::BaseController
  before_action :ensure_ai_functions_enabled
  before_action :ensure_number_not_blocked, only: :create

  def show
    render json: {
      bot_enabled: Jsit::BotStateService.new(conversation: @conversation).enabled?,
      bot_updated_by: @conversation.custom_attributes['jsit_bot_updated_by'],
      bot_updated_at: @conversation.custom_attributes['jsit_bot_updated_at']
    }
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

    enabled = params[:comando] == 'on'
    @conversation.update_columns( # rubocop:disable Rails/SkipsModelValidations
      custom_attributes: @conversation.custom_attributes.merge(
        'jsit_bot_enabled' => enabled,
        'jsit_bot_updated_by' => Current.user&.name,
        'jsit_bot_updated_at' => Time.current.iso8601
      )
    )
    create_bot_activity_message(enabled)
  end

  # Leaves a trace in the conversation timeline of who flipped the bot.
  def create_bot_activity_message(enabled)
    return if Current.user.blank?

    content = I18n.t("conversations.activity.jsit_bot.#{enabled ? 'turned_on' : 'turned_off'}", user_name: Current.user.name)
    ::Conversations::ActivityMessageJob.perform_later(
      @conversation,
      { account_id: @conversation.account_id, inbox_id: @conversation.inbox_id, message_type: :activity, content: content }
    )
  end
end
