# The contact phone number is the reliable source for the WhatsApp id: API
# inboxes (WhatsApp via n8n) store a UUID as source_id, only native WhatsApp
# inboxes keep the number there.
module Jsit::WaId
  module_function

  def for(conversation)
    phone = conversation.contact&.phone_number.to_s.gsub(/\D/, '')
    return phone if phone.present?

    source_id = conversation.contact_inbox&.source_id.to_s
    source_id.match?(/\A\+?\d+\z/) ? source_id.delete('+') : ''
  end
end
