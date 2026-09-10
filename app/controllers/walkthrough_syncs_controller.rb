class WalkthroughSyncsController < ApplicationController
  before_action :authenticate_user!

  rate_limit to: 60, within: 1.hour, store: RATE_LIMIT_STORE

  def create
    return head :unprocessable_content if oversized?

    save_file = SaveFile.for(current_user, params[:game])
    landed = Progress::Import.batch(save_file, collected: collected, bodies: bodies)
    save_file.update!(imported_at: Time.current) if final?
    render json: { marks: landed.marks, bodies: landed.bodies, done: final? }
  end

  private

  def oversized?
    [ collected, bodies ].any? { |offered| offered.size > Progress::Sync::MAX_KEYS }
  end

  def collected = offered(:collected)

  def bodies = offered(:bodies)

  def offered(key)
    value = params[key]
    value.is_a?(ActionController::Parameters) ? value.to_unsafe_h : {}
  end

  def final? = ActiveModel::Type::Boolean.new.cast(params[:final]).present?
end
