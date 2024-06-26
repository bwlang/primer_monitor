# frozen_string_literal: true

module Users
  class RegistrationsController < Devise::RegistrationsController
    # rubocop:disable Rails/LexicallyScopedActionFilter
    before_action :configure_sign_up_params, only: [:create]
    before_action :configure_account_update_params, only: [:update]
    # rubocop:enable Rails/LexicallyScopedActionFilter

    # GET /resource/sign_up
    # def new
    #   super
    # end

    # POST /resource
    # def create
    #   super
    # end

    # GET /resource/edit
    # def edit
    #   super
    # end

    # PUT /resource
    # def update
    #   super
    # end

    # DELETE /resource
    # def destroy
    #   super
    # end

    # GET /resource/cancel
    # Forces the session data which is usually expired after sign
    # in to be expired now. This is useful if the user wants to
    # cancel oauth signing in/up in the middle of the process,
    # removing all OAuth session data.
    # def cancel
    #   super
    # end

    protected

    def configure_sign_up_params
      devise_parameter_sanitizer.permit(:sign_up) do |user|
        user.permit(%i[first last email password password_confirmation send_primer_updates
                       lookback_days variant_fraction_threshold ],
                    primer_set_ids: [],
                    subscribed_detailed_geo_location_alias_ids: [])
      end
    end

    def configure_account_update_params
      devise_parameter_sanitizer.permit(:account_update) do |user|
        user.permit(%i[first last email password password_confirmation send_primer_updates
                       lookback_days variant_fraction_threshold],
                    primer_set_ids: [],
                    subscribed_detailed_geo_location_alias_ids: [])
      end
    end

    def update_resource(resource, params)
      # Require current password only if trying to change password.
      return super if params[:password].present?

      resource.update_without_password(params.except(:current_password))
    end

    # The path used after sign up.
    # def after_sign_up_path_for(resource)
    #   super(resource)
    # end

    # The path used after sign up for inactive accounts.
    # def after_inactive_sign_up_path_for(resource)
    #   super(resource)
    # end
  end
end
