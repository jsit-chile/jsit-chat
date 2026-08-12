# Numbers that must never have the bot on. 56927456123 is Sofia's own WhatsApp
# API number, so turning the bot on there makes the assistant answer itself in
# an endless loop.
module Jsit::BotBlocklist
  BLOCKED_WA_IDS = %w[56927456123].freeze

  module_function

  def blocked?(conversation)
    BLOCKED_WA_IDS.include?(Jsit::WaId.for(conversation))
  end

  # display_ids of the account conversations held with a blocked number
  def blocked_display_ids(account)
    numbers = BLOCKED_WA_IDS.flat_map { |wa_id| [wa_id, "+#{wa_id}"] }
    account.conversations.joins(:contact).where(contacts: { phone_number: numbers }).pluck(:display_id)
  end
end
