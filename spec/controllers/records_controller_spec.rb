require "rails_helper"

describe RecordsController do
  render_views

  before(:all) do
    @user = FactoryGirl.create(:user )
    @institution = FactoryGirl.create(:institution)
    puts @institution.id
    #puts @institution.logo
    puts @user.id
  end

  describe "GET index" do
    it "has a 200 status code" do
      get(:index, {}, {user_id: @user.id})
      expect(response.status).to eq(200)
    end

    #it "should redirect on index page" do
    #get(:index, {}, {user_id: @user.id})
    #expect(response).to redirect_to(records_path)

    #end
  end
end