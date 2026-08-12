// Kept in sync with Jsit::BotBlocklist. 56927456123 is Sofia's own WhatsApp API
// number, so the bot controls are hidden for it: turning the bot on there makes
// the assistant answer itself in an endless loop.
const BLOCKED_WA_IDS = ['56927456123'];

export const isBotBlockedNumber = phoneNumber =>
  BLOCKED_WA_IDS.includes(String(phoneNumber || '').replace(/\D/g, ''));
