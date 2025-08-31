class PagesController < ApplicationController

  def login_and_return
    return_to = params[:return_to].presence || root_path
    store_location_for(:user, return_to)     
    redirect_to new_user_session_path
  end

end
