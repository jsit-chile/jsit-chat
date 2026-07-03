class DashboardController < ActionController::Base
  include SwitchLocale

  GLOBAL_CONFIG_KEYS = %w[
    LOGO
    LOGO_DARK
    LOGO_THUMBNAIL
    INSTALLATION_NAME
    WIDGET_BRAND_URL
    TERMS_URL
    BRAND_URL
    BRAND_NAME
    PRIVACY_URL
    DISPLAY_MANIFEST
    CREATE_NEW_ACCOUNT_FROM_DASHBOARD
    CHATWOOT_INBOX_TOKEN
    API_CHANNEL_NAME
    API_CHANNEL_THUMBNAIL
    CLOUD_ANALYTICS_TOKEN
    DIRECT_UPLOADS_ENABLED
    MAXIMUM_FILE_UPLOAD_SIZE
    HCAPTCHA_SITE_KEY
    LOGOUT_REDIRECT_LINK
    DISABLE_USER_PROFILE_UPDATE
    DEPLOYMENT_ENV
    INSTALLATION_PRICING_PLAN
  ].freeze

  before_action :set_application_pack
  before_action :set_global_config
  before_action :set_dashboard_scripts
  around_action :switch_locale
  before_action :ensure_installation_onboarding, only: [:index]
  before_action :render_hc_if_custom_domain, only: [:index]
  before_action :ensure_html_format
  before_action :allow_iframe_embedding
  layout 'vueapp'

  def index; end

  private

  # Permite embeber el dashboard/login dentro de JSIT System (system.jsit.cl).
  # Rails envía X-Frame-Options: SAMEORIGIN por defecto, que bloquea el iframe entre
  # subdominios; lo removemos sólo aquí y restringimos el framing vía CSP
  # frame-ancestors. No afecta al widget ni a los portales (otros controladores).
  def allow_iframe_embedding
    allowed = ENV.fetch('DASHBOARD_FRAME_ANCESTORS', 'https://system.jsit.cl')
    response.headers.delete('X-Frame-Options')
    response.headers['Content-Security-Policy'] = "frame-ancestors 'self' #{allowed}"
  end

  def ensure_html_format
    render json: { error: 'Please use API routes instead of dashboard routes for JSON requests' }, status: :not_acceptable if request.format.json?
  end

  def set_global_config
    t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    base = GlobalConfig.get(*GLOBAL_CONFIG_KEYS)
    t1 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    cfg = app_config
    t2 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    @global_config = base.merge(cfg)
    Rails.logger.warn("[PERFDIAG] global_config.get=#{((t1 - t0) * 1000).round}ms app_config=#{((t2 - t1) * 1000).round}ms")
  end

  def perfdiag(label)
    t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    result = yield
    Rails.logger.warn("[PERFDIAG]   #{label}=#{((Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0) * 1000).round}ms")
    result
  end

  def set_dashboard_scripts
    @dashboard_scripts = sensitive_path? ? nil : GlobalConfig.get_value('DASHBOARD_SCRIPTS')
  end

  def ensure_installation_onboarding
    redirect_to '/installation/onboarding' if ::Redis::Alfred.get(::Redis::Alfred::CHATWOOT_INSTALLATION_ONBOARDING)
  end

  def render_hc_if_custom_domain
    domain = request.host
    return if domain == URI.parse(ENV.fetch('FRONTEND_URL', '')).host

    @portal = Portal.find_by(custom_domain: domain)
    return unless @portal

    @locale = @portal.default_locale
    render 'public/api/v1/portals/show', layout: 'portal', portal: @portal and return
  end

  def app_config
    {
      APP_VERSION: perfdiag('version') { Chatwoot.config[:version] },
      VAPID_PUBLIC_KEY: perfdiag('vapid') { VapidService.public_key },
      ENABLE_ACCOUNT_SIGNUP: perfdiag('gcs_signup') { GlobalConfigService.load('ENABLE_ACCOUNT_SIGNUP', 'false') },
      FB_APP_ID: perfdiag('gcs_fb') { GlobalConfigService.load('FB_APP_ID', '') },
      INSTAGRAM_APP_ID: GlobalConfigService.load('INSTAGRAM_APP_ID', ''),
      TIKTOK_APP_ID: GlobalConfigService.load('TIKTOK_APP_ID', ''),
      FACEBOOK_API_VERSION: perfdiag('gcs_fbver') { GlobalConfigService.load('FACEBOOK_API_VERSION', 'v18.0') },
      WHATSAPP_APP_ID: GlobalConfigService.load('WHATSAPP_APP_ID', ''),
      WHATSAPP_CONFIGURATION_ID: GlobalConfigService.load('WHATSAPP_CONFIGURATION_ID', ''),
      IS_ENTERPRISE: perfdiag('enterprise') { ChatwootApp.enterprise? },
      AZURE_APP_ID: GlobalConfigService.load('AZURE_APP_ID', ''),
      GIT_SHA: perfdiag('git_sha') { GIT_HASH },
      ALLOWED_LOGIN_METHODS: perfdiag('login_methods') { allowed_login_methods },
      ACTIVE_PLATFORM_BANNERS: perfdiag('banners') { active_platform_banners }
    }
  end

  def active_platform_banners
    return [] unless ChatwootApp.chatwoot_cloud?

    PlatformBanner.active.order(created_at: :desc).as_json(only: %i[id banner_message banner_type updated_at])
  end

  def allowed_login_methods
    methods = ['email']
    methods << 'google_oauth' if GlobalConfigService.load('ENABLE_GOOGLE_OAUTH_LOGIN', 'true').to_s != 'false'
    methods << 'saml' if ChatwootHub.pricing_plan != 'community' && GlobalConfigService.load('ENABLE_SAML_SSO_LOGIN', 'true').to_s != 'false'
    methods
  end

  def set_application_pack
    @application_pack = if request.path.include?('/auth') || request.path.include?('/login')
                          'v3app'
                        else
                          'dashboard'
                        end
  end

  def sensitive_path?
    # dont load dashboard scripts on sensitive paths like password reset
    sensitive_paths = [edit_user_password_path].freeze

    # remove app prefix
    current_path = request.path.gsub(%r{^/app}, '')

    sensitive_paths.include?(current_path)
  end
end
