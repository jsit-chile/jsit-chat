import ApiClient from './ApiClient';

class JsitBotApi extends ApiClient {
  constructor() {
    super('jsit_bot_states', { accountScoped: true });
  }
}

export default new JsitBotApi();
