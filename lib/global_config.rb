class GlobalConfig
  VERSION = 'V1'.freeze
  KEY_PREFIX = 'GLOBAL_CONFIG'.freeze
  DEFAULT_EXPIRY = 1.day

  class << self
    def get(*args)
      config_keys = args.flatten
      config = load_many_from_cache(config_keys)

      typecast_config(config)
      config.with_indifferent_access
    end

    def get_value(arg)
      load_from_cache(arg)
    end

    def clear_cache
      cached_keys = $alfred.with { |conn| conn.keys("#{VERSION}:#{KEY_PREFIX}:*") }
      (cached_keys || []).each do |cached_key|
        $alfred.with { |conn| conn.expire(cached_key, 0) }
      end
    end

    private

    def typecast_config(config)
      general_configs = ConfigLoader.new.general_configs
      config.each do |config_key, config_value|
        config_type = general_configs.find { |c| c['name'] == config_key }&.dig('type')
        config[config_key] = ActiveRecord::Type::Boolean.new.cast(config_value) if config_type == 'boolean'
      end
    end

    def load_from_cache(config_key)
      cache_key = "#{VERSION}:#{KEY_PREFIX}:#{config_key}"
      cached_value = $alfred.with { |conn| conn.get(cache_key) }

      cached_value = warm_cache(config_key) if cached_value.blank?

      JSON.parse(cached_value)['value']
    end

    # Fetches every key in a single Redis round-trip (MGET) instead of one GET
    # per key. This keeps the dashboard HTML document fast even when Redis has
    # meaningful network latency.
    def load_many_from_cache(config_keys)
      cache_keys = config_keys.map { |config_key| "#{VERSION}:#{KEY_PREFIX}:#{config_key}" }
      cached_values = $alfred.with { |conn| conn.mget(*cache_keys) }

      config = {}
      config_keys.each_with_index do |config_key, index|
        cached_value = cached_values[index]
        cached_value = warm_cache(config_key) if cached_value.blank?
        config[config_key] = JSON.parse(cached_value)['value']
      end
      config
    end

    def warm_cache(config_key)
      cache_key = "#{VERSION}:#{KEY_PREFIX}:#{config_key}"
      cached_value = { value: db_fallback(config_key) }.to_json
      $alfred.with { |conn| conn.set(cache_key, cached_value, { ex: DEFAULT_EXPIRY }) }
      cached_value
    end

    def db_fallback(config_key)
      InstallationConfig.find_by(name: config_key)&.value
    end
  end
end
