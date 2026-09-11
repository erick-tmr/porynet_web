class WalkthroughSyncsController < ApplicationController
  before_action :authenticate_user!

  rate_limit to: 60, within: 1.hour, store: RATE_LIMIT_STORE

  def create
    return head :unprocessable_content if oversized?

    landed = Progress::Import.call(current_user, guest_state)
    stamp if final?
    render json: { marks: landed.values.sum(&:marks), bodies: landed.values.sum(&:bodies),
                   done: final? }
  end

  private

  def stamp
    SaveFile.for(current_user, params[:game]).update!(imported_at: Time.current)
  end

  def guest_state
    { "collected" => games(:collected), "bodies" => games(:bodies) }
  end

  def games(key)
    offered(key).filter_map { |slug, ids| [ slug, ids ] if ids.is_a?(Hash) }.to_h
  end

  def oversized?
    guest_state.values.map { |games| games.values.sum(&:size) }
      .any? { |size| size > Progress::Sync::MAX_KEYS }
  end

  def offered(key)
    value = params[key]
    value.is_a?(ActionController::Parameters) ? value.to_unsafe_h : {}
  end

  def final? = ActiveModel::Type::Boolean.new.cast(params[:final]).present?
end
