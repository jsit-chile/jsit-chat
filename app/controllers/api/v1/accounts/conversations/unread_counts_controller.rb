class Api::V1::Accounts::Conversations::UnreadCountsController < Api::V1::Accounts::BaseController
  before_action :ensure_unread_counts_enabled, only: [:index]

  def index
    counts = ::Conversations::UnreadCounts::Counter.new(account: Current.account, user: Current.user).perform
    render json: { payload: counts }
  end

  # Account-wide count of open conversations with unread incoming messages;
  # same source of truth as the push payload badge and the jSystem badge.
  def total
    render json: { count: Current.account.conversations.open.with_unread_incoming_messages.count }
  end

  private

  def ensure_unread_counts_enabled
    return if Current.account.feature_enabled?('conversation_unread_counts')

    render json: { error: I18n.t('errors.conversations.unread_counts.feature_not_enabled') }, status: :forbidden
  end
end
