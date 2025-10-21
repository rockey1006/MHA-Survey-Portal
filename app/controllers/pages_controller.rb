class PagesController < ApplicationController
  begin
    skip_before_action :authenticate_user!
  rescue
  end

  def about; end
end
