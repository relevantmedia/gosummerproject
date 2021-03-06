class Person < ActiveRecord::Base 
  establish_connection :uscm
  
  set_table_name   "ministry_person"
  set_primary_key  "personID"
  
  has_one :current_address, :foreign_key => "fk_PersonID", :conditions => "addressType = 'current'", :class_name => '::Address'
  
  scope :not_secure, where("isSecure != 'T' or isSecure IS NULL")
  
  def emergency_address
    emergency_address1
  end
  def emergency_address=(address)
    self.emergency_address1 = address
  end
  
  def create_emergency_address
    Address.create(:fk_PersonID => self.id, :addressType => 'emergency1')
  end
  
  def create_current_address
    Address.create(:fk_PersonID => self.id, :addressType => 'current')
  end
  
  def create_permanent_address
    Address.create(:fk_PersonID => self.id, :addressType => 'permanent')
  end
  
  def region(try_target_area = true)
    region = self[:region]
    region ||= self.target_area.try(:region) if try_target_area
    region
  end
  
  #def campus=(campus_name)
    #write_attribute("campus", campus_name)
    #if target_area
      #write_attribute("region", self.school.region)
      #self.univerityState = self.school.state
    #end
  #end
  
  def target_area
    if (self.school)
      self.school
    else 
      if (campus?)
        self.school = TargetArea.find(:first,
                    :conditions => ["name = ?", campus])
      else
        self.school = nil
      end
    end
  end
  
  def validate_blogfeed
    errors.add(:blogfeed, "is invalid") if invalid_feed?
  end
  
  # empty_feed? checks to see if blogfeed has any characters that could be a feed
  def empty_feed?
    blogfeed ? blogfeed.strip.empty? : true  
  end
  
  def invalid_feed?
    FeedTools::Feed.open(blogfeed) unless empty_feed?
  rescue FeedTools::FeedAccessError
    flash[:notice] = "Invalid feed" if @my_entry
  rescue
    flash[:notice] = "Not well formed XML" if @my_entry and not empty_feed?
  end

  def human_gender
    return '' if gender.to_s.empty?
    return is_male? ? 'Male' : 'Female'
  end
  
  def is_male?
    return gender.to_i == 1
  end
  
  def is_female?
    return gender.to_i == 0
  end

  def is_high_school?
    return lastAttended == "HighSchool"
  end
  
  # "first_name last_name"
  def full_name
    first_name.to_s  + " " + last_name.to_s
  end
  
  # "nickname last_name"
  def informal_full_name
    nickname.to_s  + " " + last_name.to_s
  end
  
  def name_with_nick
    name = firstName
    if preferredName.present? && preferredName.strip != firstName.strip
      name += " (#{preferredName.strip}) "
    end
    name += ' ' + lastName.to_s
  end
  
  # "first_name middle_name last_name"
  def long_name
    l = first_name.to_s + " "
    l += middle_name.to_s + " " if middle_name
    l += last_name.to_s
  end

  # an alias for firstName using standard ruby/rails conventions
  def first_name
    firstName
  end
                
  def first_name=(f)    
    write_attribute("firstName", f)
  end

  # an alias for middleName using standard ruby/rails conventions
  def middle_name
    middleName
  end
                
  def middle_name=(m)   
    write_attribute("middleName", m)
  end
  
  # an alias for lastName using standard ruby/rails conventions
  def last_name
    lastName
  end
                
  def last_name=(l)   
    write_attribute("lastName", l)
  end
  
  #a little more than an alias.  Nickname is the preferredName if one is listed.  Otherwise it is first name                  
  def nickname
    (preferredName and not preferredName.strip.empty?) ? preferredName : firstName
  end

  #nickname is an alias for preferredName               
  def nickname=(name)   
    write_attribute("preferredName", name)
  end
  
  # an alias for yearInSchool
  def year
    yearInSchool
  end
                
  def year=(y)  
    write_attribute("yearInSchool", y)
  end
  
  def marital_status
    Person::MARITAL_STATUSES[maritalStatus]
  end
  
  MARITAL_STATUSES = {'S' => 'Single', 
                      'M' => 'Married', 
                      'D' => 'Divorced',
                      'W' => 'Widowed',
                      'P' => 'Seperated'}
  
  #set dateChanged and changedBy
  def stamp_changed
    self.dateChanged = Time.now
    self.changedBy = ApplicationController.application_name
  end
  def stamp() stamp_changed end # backwards compatibility
  def stamp_created
    self.dateCreated = Time.now
    self.createdBy = ApplicationController.application_name
  end
  
  # include FileColumnHelper
  
  # file_column picture
  def pic(size = "mini")
    if image.nil?
      "/images/nophoto_" + size + ".gif"
    else
      url_for_file_column(self, "image", size)
    end
  end
  
  def mini_pic
    pic("mini")
  end
    
  def thumb_pic
    pic("thumb")
  end
    
  def med_pic
    pic("medium")
  end

  def email
    email_address
  end
  
  def email_address
    current_address ? current_address.email : user.try(:username)
  end
  
  # This method shouldn't be needed because nightly updater should fill this in
  def is_secure?
    isSecure == 'T' ? true : false
  end
  
  # Find an exact match by email
  def self.find_exact(person, address)
    # try by address first
    person = Person.find(:first, :conditions => ["#{Address.table_name}.email = ?", address.email], :include => :current_address)
    # then try by username
    person ||= Person.find(:first, :conditions => ["#{User.table_name}.username = ?", address.email], :include => :user)
    return person
  end

  # Make sure account numbers are 9 or 10 digits long
  def self.fix_acct_no(acct_no)
    result = acct_no
    if !acct_no.blank?
      fix_length = 9
      if acct_no.ends_with?("S") || acct_no.ends_with?("s")
        fix_length = 10
      end
      pad = fix_length - acct_no.length
      result = "0" * pad + acct_no if pad > 0
    end
    result
  end
  
  def all_team_members(remove_self = false)
    my_local_level_ids = teams.collect &:id
    mmtm = TeamMember.where(:teamID => my_local_level_ids).joins(:person).order("lastName, firstName ASC")
    people = mmtm.collect(&:person).flatten.uniq
    people.delete(self) if remove_self
    return people
  end

  def to_s
    informal_full_name
  end
  
  def apply_omniauth(omniauth)
    self.firstName ||= omniauth['first_name']
    self.lastName ||= omniauth['last_name']
  end
  
  def set_region_if_campus_changed
    if changed.include?('campus') && target_area 
      self[:region] = target_area.region unless self[:region] == target_area.region
      self.universityState = target_area.state 
    end
  end
  
  def phone
    if current_address
      return current_address.cellPhone if current_address.cellPhone.present?
      return current_address.homePhone if current_address.homePhone.present?
      return current_address.workPhone if current_address.workPhone.present?
    else
      ''
    end
  end
    
  def account_balance
    return nil unless accountNo.present?
    results = connection.select_all("select f.value as balance from staffsite_staffsitepref f inner join staffsite_staffsiteprofile p on p.StaffSiteProfileID = f.fk_StaffSiteProfile where f.name = 'CURRENT_BALANCE' AND p.accountNo = '#{accountNo}'")
    if results.present?
      results.first["balance"]
    else return nil end
  end

  def updated_at() dateChanged end
  def updated_by() changedBy end
  def created_at() dateCreated end
  def created_by() createdBy end
end
