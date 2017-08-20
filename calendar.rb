require 'bundler/setup'

require 'google/apis/calendar_v3'
require 'googleauth'
require 'googleauth/stores/file_token_store'

require 'date'
require 'fileutils'
require 'active_support'
require 'active_support/core_ext'

class Calendar
  OOB_URI             = 'urn:ietf:wg:oauth:2.0:oob'
  APPLICATION_NAME    = 'ScheduleReminder'
  CLIENT_SECRETS_PATH = 'client_secret.json'
  CREDENTIALS_PATH    = File.join(Dir.home, '.credentials', "schedule_reminder.yaml")
  SCOPE               = Google::Apis::CalendarV3::AUTH_CALENDAR_READONLY
  DEFAULT_TIME_RANGE  = 10.minutes

  def initialize(calendar_ids)
    cert_path = Gem.loaded_specs['google-api-client'].full_gem_path+'/lib/cacerts.pem'
    ENV['SSL_CERT_FILE'] = cert_path

    # Initialize the API
    @service = Google::Apis::CalendarV3::CalendarService.new
    @service.client_options.application_name = APPLICATION_NAME
    @service.authorization = authorize

    @calendar_ids = calendar_ids
  end

  def authorize
    FileUtils.mkdir_p(File.dirname(CREDENTIALS_PATH))

    client_id   = Google::Auth::ClientId.from_file(CLIENT_SECRETS_PATH)
    token_store = Google::Auth::Stores::FileTokenStore.new(file: CREDENTIALS_PATH)
    authorizer  = Google::Auth::UserAuthorizer.new(client_id, SCOPE, token_store)
    user_id     = 'default'
    credentials = authorizer.get_credentials(user_id)

    if credentials.nil?
      url = authorizer.get_authorization_url(base_url: OOB_URI)
      puts "Open the following URL in the browser and enter the resulting code after authorization"
      puts url
      code = gets
      credentials = authorizer.get_and_store_credentials_from_code(user_id: user_id, code: code, base_url: OOB_URI)
    end

    credentials
  end

  def list_events(max_results, time_range = DEFAULT_TIME_RANGE, exclude_already_started = true)
    now = DateTime.now
    time_min = now.iso8601
    time_max = (now + time_range).iso8601
    events = []
    @calendar_ids.each do |calendar_id|
      response = @service.list_events(
                   calendar_id,
                   max_results:   max_results,
                   single_events: true,
                   order_by:      'startTime',
                   time_min:      time_min,
                   time_max:      time_max
                 )
      events.concat(response.items)
    end

    events.sort! do |event_a, event_b|
      event_a.start.date_time <=> event_b.start.date_time
    end

    return events unless exclude_already_started

    events.select do |event|
      event.start.date_time >= now
    end
  end
end

if $0 == __FILE__
  calendar_ids = ['XXXXXXXXXXXXXXXXXXXX']
  calendar = Calendar.new(calendar_ids)
  events = calendar.list_events(10, 30.minutes)

  if events.empty?
    puts 'No events found.'
    exit
  end

  events.each do |event|
    start = event.start.date || event.start.date_time
    puts "#{start} - #{event.summary}"
    puts "creator: #{event.creator.display_name} id: #{event.id}"
  end
end
