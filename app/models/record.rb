require 'rubygems'
require 'zip/zip'

class Record < ActiveRecord::Base
  include RecordHelper
  
  has_many :creators, :dependent => :destroy
  has_many :contributors
  has_many :descriptions
  has_many :subjects, :dependent => :destroy
  has_many :alternateIdentifiers
  has_many :datauploads
  has_many :relations
  has_many :submissionLogs
  has_many :uploads,   :dependent => :destroy
  has_many :citations, :dependent => :destroy
 

 # accepts_nested_attributes_for :creators, allow_destroy: true
  belongs_to :user
  belongs_to :institution
  
  attr_accessible :identifier, :identifierType, :publicationyear, :publisher, 
                  :resourcetype, :rights, :rights_uri, :title, :local_id,:abstract, 
                  :methods
  
  
  validate :must_have_creators

  #the use of the symbol ^ is to avoid the column name to be displayed along with the error message, custom-err-msg gem
  validates_presence_of :title, :message => "^You must include a title for your submission."
  validates_presence_of :resourcetype, :message => "^Please specify the data type."
  validates_presence_of :rights, :message => "^Please specify the rights."
  validates_presence_of :rights_uri, :message => "^Please specify the rights URI."
  validates_presence_of :creators, :message => "^You must add at least one creator."

  before_save :mark_subjects_for_destruction, 
              :mark_citations_for_destruction, 
              :mark_creators_for_destruction

  accepts_nested_attributes_for :creators, allow_destroy: true, reject_if: proc { |attributes| attributes.all? { |key, value| key == '_destroy' || value.blank? } }
  attr_accessible :creators_attributes

  accepts_nested_attributes_for :citations, allow_destroy: true, reject_if: proc { |attributes| attributes.all? { |key, value| key == '_destroy' || value.blank? } }
  attr_accessible :citations_attributes

  accepts_nested_attributes_for :subjects, allow_destroy: true, reject_if: proc { |attributes| attributes.all? { |key, value| key == '_destroy' || value.blank? } }
  attr_accessible :subjects_attributes



  def must_have_creators
    valid = 0
    if creators.nil?
      errors.add(:base, 'You must add at least one creator.')
    else
      creators.each do |creator|
        if !creator.creatorName.blank?
          valid = 1
        end
      end
      if valid == 0
        errors.add(:base, 'You must add at least one creator.')
      end
    end
  end


  def mark_subjects_for_destruction
    subjects.each {|subject|
    if subject.subjectName.blank?
      subject.mark_for_destruction
    end
    }
  end


  def mark_citations_for_destruction
    citations.each {|citation|
      if citation.citationName.blank?
        citation.mark_for_destruction
      end
    }
  end


  def mark_creators_for_destruction
    creators.each {|creator|
      if creator.creatorName.blank? || creator.creatorName == "" || creator.creatorName.nil?
        creator.mark_for_destruction
      end
    }
  end


  def set_local_id
    self.local_id = (0...10).map{ ('a'..'z').to_a[rand(26)] }.join
  end
  

  def create_record_directory
    FileUtils.mkdir("#{Rails.root}/#{DATASHARE_CONFIG['uploads_dir']}/#{self.local_id}")
  end
  



  def review
    


    @total_size = 0
    self.uploads.each do |u|
      @total_size = @total_size + u.upload_file_size
    end
    if ( !self.submissionLogs.empty? && !self.submissionLogs.nil?)
      self.submissionLogs.each do |log|
          if ( !log.uploadArchives.empty? && !log.uploadArchives.empty?)
            log.uploadArchives.each do |a|
              @total_size = @total_size + a.upload_file_size.to_i     
            end
          end
      end
    end


    xml_content = File.new("#{Rails.root}/#{DATASHARE_CONFIG['uploads_dir']}/#{self.local_id}/noko.xml", "w:ASCII-8BIT")
    
    builder = Nokogiri::XML::Builder.new(:encoding => 'UTF-8') do |xml|
      xml.resource( 'xmlns' => 'http://datacite.org/schema/kernel-3', 
                    'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance',
                    'xsi:schemaLocation' => 'http://datacite.org/schema/kernel-3 http://schema.datacite.org/meta/kernel-3/metadata.xsd') {
        xml.identifier('identifierType' => 'DOI') {}
        xml.creators{
          self.creators.each do |c|
            xml.creator {
              xml.creatorName "#{c.creatorName.gsub(/\r/,"")}"
            }
          end
        }
        xml.titles {
          xml.title "#{self.title}"
        }
        xml.pubisher "#{self.publisher}"
        xml.publicationYear "#{self.publicationyear}"
        xml.subjects {
          self.subjects.each do |s|
            xml.subject "#{s.subjectName.gsub(/\r/,"")}"
          end
        }
        xml.contributors {
          self.contributors.each do |c|
            xml.contributor {
              xml.contributorName "#{c.contributorName.gsub(/\r/,"")}"
            }
          end
        }
        xml.resourceType "#{resourceTypeGeneral(self.resourcetype)}"
        xml.size @total_size


        # xml.Option("b" => "hive"){ xml.text("hello") }

        xml.rightsList { 
          xml.rights("rightsURI" => "#{CGI::escapeHTML(self.rights_uri)}") { 
            xml.text("#{CGI::escapeHTML(self.rights)}") 
          }
        }

        xml.descriptions{
          unless self.abstract.nil?
            xml.description "#{CGI::escapeHTML(self.abstract.gsub(/\r/,""))}"
          end
          unless self.methods.nil?
            xml.description "#{CGI::escapeHTML(self.methods.gsub(/\r/,""))}"
          end
          self.descriptions.each do |d|
            xml.description "#{CGI::escapeHTML(d.descriptionText.gsub(/\r/,""))}"
          end
        }
      }
    end
    puts builder.to_xml

    # f.puts "<descriptions>" 
    #  if !self.abstract.nil?
    #    f.puts "<description descriptionType=\"Abstract\">#{CGI::escapeHTML(self.abstract.gsub(/\r/,""))}</description>"
    #  end
    #  if !self.methods.nil?
    #    f.puts "<description descriptionType=\"Methods\">#{CGI::escapeHTML(self.methods.gsub(/\r/,""))}</description>"
    #  end
    #  self.descriptions.each { |a| f.puts "<description descriptionType=\"SeriesInformation\">#{CGI::escapeHTML(a.descriptionText.gsub(/\r/,""))}</description>" }      
     
    #  f.puts "</descriptions>"

    File.open("#{Rails.root}/#{DATASHARE_CONFIG['uploads_dir']}/#{self.local_id}/noko.xml", 'w') { |f| f.print(builder.to_xml) }


     f = File.new("#{Rails.root}/#{DATASHARE_CONFIG['uploads_dir']}/#{self.local_id}/datacite.xml", "w:ASCII-8BIT")
    
     f.puts "<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
     f.puts "<resource xmlns=\"http://datacite.org/schema/kernel-3\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xsi:schemaLocation=\"http://datacite.org/schema/kernel-3 http://schema.datacite.org/meta/kernel-3/metadata.xsd\">"
     
     f.puts "<identifier identifierType=\"DOI\"></identifier>"
     
     # creators - datacite: multiple, mandatory
     f.puts "<creators>"
     self.creators.each { |a| f.puts "<creator><creatorName>#{a.creatorName.gsub(/\r/,"")}</creatorName></creator>"}

     f.puts "</creators>"

     f.puts "<titles>"
     f.puts "<title>#{self.title}</title>"
     f.puts "</titles>"
     
     # publisher - datacite: single, mandatory
     f.puts "<publisher>#{self.publisher}</publisher>"
     
     # publication year - datacite: single, mandatory
     f.puts "<publicationYear>#{self.publicationyear}</publicationYear>"
     
     # subjects - datacite: multiple, optional
     f.puts "<subjects>"

     self.subjects.each { |a| f.puts "<subject>#{a.subjectName.gsub(/\r/,"")}</subject>" unless a.subjectName.nil?} 
     f.puts "</subjects>"
    f.puts "<contributors>"
    self.contributors.each do |c| 
      f.puts "<contributor contributorType=\"DataManager\">"
      f.puts "<contributorName>#{c.contributorName.gsub(/\r/,"")}</contributorName></contributor>"
    end
     f.puts "</contributors>"
     f.puts "<resourceType resourceTypeGeneral=\"#{resourceTypeGeneral(self.resourcetype)}\">#{resourceType(self.resourcetype)}</resourceType>"
    f.puts "<size>#{@total_size}</size>"
     
    f.puts "<rightsList>"
    f.puts "<rights rightsURI=\"#{CGI::escapeHTML(self.rights_uri)}\">#{CGI::escapeHTML(self.rights)}</rights>"
    f.puts "</rightsList>"

     f.puts "<descriptions>" 
     if !self.abstract.nil?
       f.puts "<description descriptionType=\"Abstract\">#{CGI::escapeHTML(self.abstract.gsub(/\r/,""))}</description>"
     end
     if !self.methods.nil?
       f.puts "<description descriptionType=\"Methods\">#{CGI::escapeHTML(self.methods.gsub(/\r/,""))}</description>"
     end
     self.descriptions.each { |a| f.puts "<description descriptionType=\"SeriesInformation\">#{CGI::escapeHTML(a.descriptionText.gsub(/\r/,""))}</description>" }      
     
     f.puts "</descriptions>"

     f.puts "</resource>"   
          
     f.close
     
     #return contents of file as string
     # File.open("#{Rails.root}/#{DATASHARE_CONFIG['uploads_dir']}/#{self.local_id}/datacite.xml", "rb").read

     f = File.open("#{Rails.root}/#{DATASHARE_CONFIG['uploads_dir']}/#{self.local_id}/datacite.xml", "r")
      while line = f.gets
          puts line
      end
      f.close



      # <% @record.uploads.each do |dataupload| %>
        # <li><%= dataupload.upload_file_name %> (<%= number_to_human_size(dataupload.upload_file_size) %>)</li>    
    # <% end %>
    # @total_size = 0
    # self.uploads.each do |u|
    #   @total_size = @total_size + u.upload_file_size
    # end
    # if ( !self.submissionLogs.empty? && !self.submissionLogs.nil?)
    #   self.submissionLogs.each do |log|
    #       if ( !log.uploadArchives.empty? && !log.uploadArchives.empty?)
    #         log.uploadArchives.each do |a|
    #           @total_size = @total_size + a.upload_file_size.to_i     
    #         end
    #       end
    #   end
    # end

   end




   def generate_merritt_zip  
    
     file_path = "#{Rails.root}/#{DATASHARE_CONFIG['uploads_dir']}/#{self.local_id}"
    
     if File.exist?("#{file_path}/#{self.local_id}.zip")
       File.delete("#{file_path}/#{self.local_id}.zip")
     end
     
     zipfile_name = "#{file_path}/#{self.local_id}.zip"

     # target link and doi are generated by merritt
     # they are included here only for testing
     # uncomment if you need them in the archive (ie, if your repository does not supply these)
     f = File.new("#{file_path}/target_link", "w")  
     f.puts "http://localhost:3000/download_merritt_file/#{self.local_id}.zip"
     f.close

     f = File.new("#{file_path}/doi", "w")  
     f.puts "doi:10.7272/Q6057CV6"
     f.close

     f = File.new("#{file_path}/mrt-datacite.xml", "wb") 
     f.puts self.review
     f.close

     Zip::ZipFile.open(zipfile_name, Zip::ZipFile::CREATE) do |zipfile|       
       zipfile.add("mrt-datacite.xml", "#{file_path}/mrt-datacite.xml")
       
       self.purge_temp_files
       
       self.uploads.each do |d|  
          zipfile.add("#{d.upload_file_name}", "#{file_path}/#{d.upload_file_name}")
       end
     end

     # clean up all temp files (again, required because of the glitch in chunked file uploads)
     FileUtils.rm Dir[file_path + "/temp_*"]

   end


   # keep metadata records, but get rid of files that are no longer needed for local storate
   # (storage is intended only until records are uploaded to merritt)
   def purge_files(submission_log_id)
     
    uploads = Upload.find_all_by_record_id(self.id)
     
     # archive the file information for submission logs
    uploads.each do |u|
       upload_archive = UploadArchive.new
       upload_archive.submission_log_id = submission_log_id
       upload_archive.upload_file_name = u.upload_file_name
       upload_archive.upload_file_size = u.upload_file_size
       upload_archive.upload_content_type = u.upload_content_type
       upload_archive.save
     end
     
     Upload.delete_all(:record_id => self.id)

     file_path = "#{Rails.root}/#{DATASHARE_CONFIG['uploads_dir']}/#{self.local_id}"

     # delete the files from local storage now that they have been submitted to merritt
     if File.exist?("#{file_path}")
       FileUtils.rm_rf Dir.glob("#{file_path}/*")
     end
   end


   def send_archive_to_merritt(external_id)
    
     # tics will execute, for now, just print to screen
      # note that the 2>&1 is to redirect sterr to stout

    @user = User.find_by_external_id(external_id)
    #@user = User.find(session[:user_id])

    if @user
      @user_email = @user.email
    else
      @user_email = nil
    end

     #campus = Record.id_to_campus(external_id)
     campus = @user.institution.campus
     
     if (!campus) then
       return false
     end
     
     merritt_endpoint = MERRITT_CONFIG["merritt_#{campus}_endpoint"]
     merritt_username = MERRITT_CONFIG["merritt_#{campus}_username"]
     merritt_password = MERRITT_CONFIG["merritt_#{campus}_password"]
     merritt_profile = MERRITT_CONFIG["merritt_#{campus}_profile"]

    if @user_email.nil?
      sys_output = "curl --insecure --verbose -u #{merritt_username}:#{merritt_password} -F \"file=@./#{DATASHARE_CONFIG['uploads_dir']}/#{self.local_id}/#{self.local_id}.zip\" -F \"type=container\" -F \"submitter=Dash/#{external_id}\" -F \"responseForm=xml\" -F \"profile=#{merritt_profile}\" -F \"localIdentifier=#{self.local_id}\" #{merritt_endpoint} 2>&1"  
    else     
      sys_output = "curl --insecure --verbose -u #{merritt_username}:#{merritt_password} -F \"file=@./#{DATASHARE_CONFIG['uploads_dir']}/#{self.local_id}/#{self.local_id}.zip\" -F \"notification=#{@user_email}\" -F \"type=container\" -F \"submitter=Dash/#{external_id}\" -F \"responseForm=xml\" -F \"profile=#{merritt_profile}\" -F \"localIdentifier=#{self.local_id}\" #{merritt_endpoint} 2>&1"
    end

     return sys_output  

   end
   

  


   def required_fields
    
      required_fields = Array.new
    
      if self.creators.nil? || self.creators.empty?
        required_fields << "Record must specify at least one creator."
      end

      # should we allow multiple titles?  datacite does...
      # we're only allowing one title per record

      if self.title.nil? || self.title.blank?
        required_fields << "Record must have a title."
      end

      # publisher - datacite: single, mandatory
      if self.publisher.nil? || self.publisher.blank?
        required_fields << "Record must have a publisher."
      end

      # publication year - datacite: single, mandatory
      if self.publicationyear.nil?
        required_fields << "Record must have a publication year."
      end

      #contributors - datacite: multiple, optional, mandatory contributorType attribute
      # we will require contributors for datashare

      if self.contributors.nil? || self.contributors.empty?
        #required_fields << "Record must specify at least one contributor"
      end
    
      return required_fields
   end
   

   def recommended_fields
   
      # recommended_fields = Array.new
      recommended_fields = ""
      fields = ""

      # initial_sentence = "Missing recommended field(s): "
      initial_sentence = "Consider adding these recommended field(s): "
            
      if self.subjects.nil? || self.subjects.empty?
        fields << "keywords"
      end
      
      if self.abstract == "" || self.abstract.nil?
        fields << ", " unless fields.empty?
        fields << "abstract"
      end

      if self.methods == "" || self.methods.nil?
        fields << ", " unless fields.empty?
        fields << "methods"
      end

      if self.citations.nil? || self.citations.empty?
        fields << ", " unless fields.empty?
        fields << "citations"
      end

      unless fields.empty?
        fields << "."
        recommended_fields = initial_sentence + fields
      end  
 
      return recommended_fields
   
   end
  
  
  # temp files created for multipart uploads
  def purge_temp_files
    
    file_path = "#{Rails.root}/#{DATASHARE_CONFIG['uploads_dir']}/#{self.local_id}"
    
    self.uploads.each do |d| 
       
        # a temporary terrible hack to avoid the file corruption problem
        # on chunked uploads     
        
        if File.exist?(file_path + "/temp_" + d.upload_file_name)
          File.delete(file_path + "/" + d.upload_file_name)
          File.rename(file_path + "/temp_" + d.upload_file_name, file_path + "/" + d.upload_file_name)
        end
     end
  end
  
  
end
