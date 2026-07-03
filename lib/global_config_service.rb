class GlobalConfigService
  def self.load(config_key, default_value)
    config = GlobalConfig.get(config_key)[config_key]
    # `nil?` instead of `present?`: boolean configs stored as `false` (e.g.
    # ENABLE_ACCOUNT_SIGNUP) would otherwise fall through on every request and
    # trigger first_or_create + GlobalConfig.clear_cache, wiping the whole
    # config cache each time (permanent cache-thrash on the dashboard path).
    return config unless config.nil?

    # To support migrating existing instance relying on env variables
    # TODO: deprecate this later down the line
    config_value = ENV.fetch(config_key) { default_value }

    return if config_value.blank?

    i = InstallationConfig.where(name: config_key).first_or_create(value: config_value, locked: false)
    # To clear a nil value that might have been cached in the previous call.
    # Only when a record was actually created — clearing on every lookup of an
    # existing (nil-valued) row would wipe the cache on each request.
    GlobalConfig.clear_cache if i.previously_new_record?
    i.value
  end

  def self.account_signup_enabled?
    load('ENABLE_ACCOUNT_SIGNUP', 'false').to_s != 'false'
  end
end
