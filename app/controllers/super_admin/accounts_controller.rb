class SuperAdmin::AccountsController < SuperAdmin::ApplicationController
  # Overwrite any of the RESTful controller actions to implement custom behavior
  # For example, you may want to send an email after a foo is updated.
  #
  # def update
  #   super
  #   send_foo_updated_email(requested_resource)
  # end

  # Override this method to specify custom lookup behavior.
  # This will be used to set the resource for the `show`, `edit`, and `update`
  # actions.
  #
  # def find_resource(param)
  #   Foo.find_by!(slug: param)
  # end

  # The result of this lookup will be available as `requested_resource`

  # Override this if you have certain roles that require a subset
  # this will be used to set the records shown on the `index` action.
  #
  # def scoped_resource
  #   if current_user.super_admin?
  #     resource_class
  #   else
  #     resource_class.with_less_stuff
  #   end
  # end

  # Override `resource_params` if you want to transform the submitted
  # data before it's persisted. For example, the following would turn all
  # empty values into nil values. It uses other APIs such as `resource_class`
  # and `dashboard`:
  #
  def resource_params
    permitted_params = super
    permitted_params[:limits] = permitted_params[:limits].to_h.compact
    permitted_params[:selected_feature_flags] = params[:enabled_features].keys.map(&:to_sym) if params[:enabled_features].present?
    permitted_params
  end

  # See https://administrate-prototype.herokuapp.com/customizing_controller_actions
  # for more information

  def index
    if request.format.json?
      query = params[:search].to_s.strip
      resources = Account.where('name ILIKE ? OR id::text ILIKE ?', "%#{query}%", "%#{query}%")
                         .order(id: :desc).limit(50)
      return render json: { resources: resources.map { |r| { id: r.id, dashboard_display_name: "#{r.id} — #{r.name}" } } }
    end
    super
  end

  def seed
    Internal::SeedAccountJob.perform_later(requested_resource)
    # rubocop:disable Rails/I18nLocaleTexts
    redirect_back(fallback_location: [namespace, requested_resource], notice: 'Account seeding triggered')
    # rubocop:enable Rails/I18nLocaleTexts
  end

  def reset_cache
    requested_resource.reset_cache_keys
    # rubocop:disable Rails/I18nLocaleTexts
    redirect_back(fallback_location: [namespace, requested_resource], notice: 'Cache keys cleared')
    # rubocop:enable Rails/I18nLocaleTexts
  end

  # Flips the account level switch for the JSIT bot controls in the dashboard.
  def toggle_ai_functions
    account = requested_resource
    enabled = !account.jsit_ai_functions
    account.update!(custom_attributes: account.custom_attributes.merge('jsit_ai_functions' => enabled))

    notice_key = enabled ? 'super_admin.ai_functions_enabled' : 'super_admin.ai_functions_disabled'
    redirect_back(fallback_location: [namespace, :accounts], notice: I18n.t(notice_key, name: account.name))
  end

  # Flips whether the bot answers every conversation of the account by default.
  # jWorkflows reads the same Redis key either way, only the meaning changes: on
  # these accounts the key marks the paused conversations.
  def toggle_bot_default
    account = requested_resource
    enabled = !account.jsit_bot_default_on
    account.update!(custom_attributes: account.custom_attributes.merge('jsit_bot_default_on' => enabled))

    notice_key = enabled ? 'super_admin.bot_default_on' : 'super_admin.bot_default_off'
    redirect_back(fallback_location: [namespace, :accounts], notice: I18n.t(notice_key, name: account.name))
  end

  def destroy
    account = Account.find(params[:id])

    DeleteObjectJob.perform_later(account) if account.present?
    # rubocop:disable Rails/I18nLocaleTexts
    redirect_back(fallback_location: [namespace, requested_resource], notice: 'Account deletion is in progress.')
    # rubocop:enable Rails/I18nLocaleTexts
  end
end

SuperAdmin::AccountsController.prepend_mod_with('SuperAdmin::AccountsController')
