module Enterprise::Internal::CheckNewVersionsJob
  def perform
    super
    update_plan_info
    reconcile_premium_config_and_features
  end

  private

  def update_plan_info
    return if @instance_info.blank?

    # White-label self-hosted override: allow forcing the plan via ENV so the
    # periodic hub sync cannot downgrade us to "community" (which would reset the
    # branding configs — INSTALLATION_NAME, LOGO — back to Chatwoot defaults).
    plan = ENV.fetch('INSTALLATION_PRICING_PLAN', nil).presence || @instance_info['plan']
    plan_quantity = ENV.fetch('INSTALLATION_PRICING_PLAN_QUANTITY', nil).presence || @instance_info['plan_quantity']
    update_installation_config(key: 'INSTALLATION_PRICING_PLAN', value: plan)
    update_installation_config(key: 'INSTALLATION_PRICING_PLAN_QUANTITY', value: plan_quantity)
    update_installation_config(key: 'CHATWOOT_SUPPORT_WEBSITE_TOKEN', value: @instance_info['chatwoot_support_website_token'])
    update_installation_config(key: 'CHATWOOT_SUPPORT_IDENTIFIER_HASH', value: @instance_info['chatwoot_support_identifier_hash'])
    update_installation_config(key: 'CHATWOOT_SUPPORT_SCRIPT_URL', value: @instance_info['chatwoot_support_script_url'])
  end

  def update_installation_config(key:, value:)
    config = InstallationConfig.find_or_initialize_by(name: key)
    config.value = value
    config.locked = true
    config.save!
  end

  def reconcile_premium_config_and_features
    Internal::ReconcilePlanConfigService.new.perform
  end
end
