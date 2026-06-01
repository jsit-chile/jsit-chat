class SuperAdmin::UsersController < SuperAdmin::ApplicationController
  # Overwrite any of the RESTful controller actions to implement custom behavior
  # For example, you may want to send an email after a foo is updated.

  def index
    if request.format.json?
      query = params[:search].to_s.strip
      resources = User.where('name ILIKE ? OR email ILIKE ? OR id::text ILIKE ?',
                             "%#{query}%", "%#{query}%", "%#{query}%")
                      .order(id: :desc).limit(50)
      return render json: { resources: resources.map { |r| { id: r.id, dashboard_display_name: "#{r.email} — #{r.name}" } } }
    end
    super
  end

  def create
    resource = resource_class.new(resource_params)
    authorize_resource(resource)

    if resource.save
      redirect_to super_admin_user_path(resource), notice: translate_with_resource('create.success')
    else
      notice = resource.errors.full_messages.first
      redirect_to new_super_admin_user_path, notice: notice
    end
  end

  def update
    requested_resource.skip_reconfirmation! if resource_params[:confirmed_at].present?
    super
  end

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

  def destroy_avatar
    avatar = requested_resource.avatar
    avatar.purge
    redirect_back(fallback_location: super_admin_users_path)
  end

  def scoped_resource
    resource_class.with_attached_avatar
  end

  def resource_params
    permitted_params = super
    permitted_params.delete(:password) if permitted_params[:password].blank?
    # 'User' is a UI sentinel for a regular agent/administrator (selectize drops
    # empty-value options); STI expects nil type for the base User class.
    permitted_params[:type] = nil if permitted_params[:type] == 'User'
    permitted_params
  end

  # See https://administrate-prototype.herokuapp.com/customizing_controller_actions
  # for more information
  def find_resource(param)
    super.becomes(User)
  end
end
