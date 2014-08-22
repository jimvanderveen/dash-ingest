require 'spec_helper'
require 'database_cleaner'
# require "selenium-webdriver"

feature 'user' do


	before(:each) do
    
    institution = FactoryGirl.create(:institution)
  	institution.save

  	user = FactoryGirl.create(:user)
  	user.first_name = "John"
  	user.last_name = "Smith"
  	user.institution_id = institution.id
  	user.save

    visit '/records'
    
  end
	
	  
  scenario 'goes to the home page' do
    visit root_path

    expect(page).to have_content 'My Datasets'   
  end

 
  scenario 'goes to the new dataset page' do
  	visit root_path
  	click_link 'new_record'
		
   	expect(page).to have_content "Describe Your Dataset"
  end


  scenario 'triggers validation errors if required attributes are missing when adding a new record' do
  	visit root_path
  	click_link 'new_record' 
  	click_on "save_and_continue"
  	
  	expect(page).to have_content "Please specify the data type."
  	expect(page).to have_content "You must include a title for your submission."
  	expect(page).to have_content "You must add at least one creator."
	end


  scenario 'adds record metadata with valid attributes' do
  	visit root_path
  	click_link 'new_record'
  	fill_in 'record_title', :with => 'Rose' 
  	select 'Image', :from => 'record_resourcetype' 
  	fill_in 'record_creators_attributes_0_creatorName', :with => 'John Smith' 
  	click_on "save_and_continue"

  	expect(page).to have_content "Upload Your Dataset"
	end



end