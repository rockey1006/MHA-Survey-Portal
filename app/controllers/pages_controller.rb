class PagesController < ApplicationController
  begin
    skip_before_action :authenticate_user!
  rescue
  end

  def about; end

  def faq; end

  def maintenance
    render status: :service_unavailable
  end
end
