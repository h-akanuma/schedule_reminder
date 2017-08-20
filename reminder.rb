require 'bundler/setup'
require 'active_support'
require 'active_support/core_ext'
require './calendar.rb'
require './notifier.rb'

class Reminder
  MAX_RESULTS        = 10
  TIME_RANGE         = 10.minutes
  SPEECH_TEMPLATE_JP = '間も無く、%sが始まる時間です。'
  CALENDAR_IDS       = ['XXXXXXXXXXXXXXXXXXXXXXXX']

  def initialize
    @calender = Calendar.new(CALENDAR_IDS)
    @notifier = Notifier.new
    @reminded_event_ids = []
    @log = Logger.new('logs/reminder.log')
    @log.debug('Initialized Reminder.')
  end

  def remind
    events = @calender.list_events(MAX_RESULTS, TIME_RANGE)

    if events.empty?
      @log.debug('No events found.')
      return
    end

    event = events.first
    start = event.start.date || event.start.date_time

    if @reminded_event_ids.include?(event.id)
      @log.debug("AlreadyReminded: #{start} - #{event.summary} id: #{event.id}")
      return
    end

    @notifier.speech(SPEECH_TEMPLATE_JP % event.summary)
    @reminded_event_ids << event.id
    @log.info("Reminded: #{start} - #{event.summary} id: #{event.id}")
  end
end

if $0 == __FILE__
  reminder = Reminder.new
  loop do
    reminder.remind
    sleep(1.minute)
  end
end
