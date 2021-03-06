# frozen_string_literal: true

class ApplicationController < ActionController::Base
  include Routes
  include ParamsHelper
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  before_action :admins_only if Lilsis::Application.config.admins_only

  before_action :set_paper_trail_whodunnit

  before_action :configure_permitted_parameters, if: :devise_controller?

  rescue_from Exceptions::PermissionError do
    render 'errors/permission', status: :forbidden
  end

  rescue_from Exceptions::RestrictedUserError do
    redirect_to home_dashboard_path, notice: <<~NOTICE
      Your account has been restricted. This might be because we think you are posting spam. If that's a mistake, please contact us
    NOTICE
  end

  rescue_from Exceptions::NotFoundError do
    render 'errors/not_found', status: :not_found
  end

  rescue_from ActiveRecord::RecordNotFound do
    render 'errors/not_found', status: :not_found
  end

  rescue_from ActionController::RoutingError do
    raise if Rails.env.development?
    render 'errors/not_found', status: :not_found
  end

  rescue_from Exceptions::UnauthorizedBulkRequest do |exception|
    # for use only with JSON requests
    render json: { errors: ['title' => exception.message] }, status: :unauthorized
  end

  rescue_from Exceptions::MergedEntityError do |e|
    EntitiesController::TABS.include?(action_name) ?
      redirect_to(send("#{action_name}_entity_path", e.merged_entity)) :
      redirect_to(entity_path(e.merged_entity))
  end

  def admins_only
    check_permission 'admin'
  end

  def auth
    redirect_to '/login' unless user_signed_in?
  end

  def block_restricted_user_access
    raise Exceptions::RestrictedUserError if current_user.restricted?
  end

  def check_permission(name)
    raise Exceptions::PermissionError unless current_user.present?
    raise Exceptions::RestrictedUserError if current_user.restricted?
    raise Exceptions::PermissionError unless current_user.has_legacy_permission(name) || current_user.has_legacy_permission("admin")
  end

  # Array, Integer -> Void
  def block_unless_bulker(resources = [], limit = 0)
    # users who aren't admins or 'bulkers' may not create more than `limit` resources at a time
    if (resources.present? && resources.length > limit) && !(current_user.bulker? || current_user.admin?)
      raise Exceptions::UnauthorizedBulkRequest
    end
  end

  def not_found
    raise Exceptions::NotFoundError
  end

  def dismiss_alert(id)
    session[:dismissed_alerts] ||= []
    session[:dismissed_alerts] << id
  end

  def clear_dismissed_alerts
    session[:dismissed_alerts] = []
  end

  ##
  # Entity Queue
  # TODO: Delete this
  # see: entities_controller, images_controller, articles

  def ensure_entity_queue(key)
    session[:entity_queues] = {} unless session[:entity_queues].present?
    session[:entity_queues][key] = { entity_ids: [] } unless session[:entity_queues][key].present?
  end

  def set_entity_queue(key, entity_ids, list_id=nil)
    ensure_entity_queue(key)
    session[:entity_queues][key][:entity_ids] = entity_ids
    session[:entity_queues][key][:list_id] = list_id if list_id
    entity_ids
  end

  def next_entity_in_queue(key)
    ensure_entity_queue(key)
    remove_skipped_from_queue(key)
    session[:entity_queues][key][:entity_ids].shift
  end

  def entity_queue_count(key)
    ensure_entity_queue(key)
    session[:entity_queues][key][:entity_ids].count
  end

  def remove_skipped_from_queue(key)
    session[:entity_queues][key][:entity_ids] = QueueEntity.filter_skipped(key, session[:entity_queues][key][:entity_ids])
  end

  def skip_queue_entity(key, entity_id)
    QueueEntity.skip_entity(key, entity_id, current_user.id)
  end

  ##
  # merge
  #
  def merge_last_user(attrs)
    attrs.merge(last_user_id: current_user.sf_guard_user_id)
  end

  protected

  def set_page
    @page = params[:page].presence&.to_i || 1
  end

  def set_entity(skope = :itself)
    @entity = Entity.find_with_merges(id: params[:id], skope: skope)
  end

  def set_cache_control(time = 1.hour)
    expires_in(time, public: true, must_revalidate: true)
  end

  def value_for_param(param, default_value, transform = :itself)
    params[param].present? ? params[param].send(transform) : default_value
  end

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:account_update, keys: [:about_me])
  end

  def api_request?
    request_type && request_type == 'API'
  end

  def request_type
    request.headers['Littlesis-Request-Type']
  end

  def redirect_to_dashboard
    redirect_to home_dashboard_path
  end
end
