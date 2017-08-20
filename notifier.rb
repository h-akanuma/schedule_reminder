require 'bundler/setup'
require 'aws-sdk'
require 'open3'
require 'digest/md5'

class Notifier
  VOICE_DIR = '/home/root/work/schedule_reminder/voices'

  REGION            = 'us-east-1'
  ACCESS_KEY_ID     = ENV['ACCESS_KEY_ID']
  SECRET_ACCESS_KEY = ENV['SECRET_ACCESS_KEY']
  VOICE_ID_JP       = 'Mizuki'

  def initialize
    Aws.config.update({
      region:      REGION,
      credentials: Aws::Credentials.new(ACCESS_KEY_ID, SECRET_ACCESS_KEY)
    })

    @client = Aws::Polly::Client.new
  end

  def speech(text)
    text_hash = Digest::MD5.hexdigest(text)
    target_file = "#{VOICE_DIR}/#{text_hash}"

    synthesize(text, target_file)
    convert(target_file)
    play(target_file)
  end

  def synthesize(text, target_file)
    resp = @client.synthesize_speech({
      response_target: "#{target_file}.mp3",
      output_format:   'mp3',
      voice_id:        VOICE_ID_JP,
      text:            text
    })
  end

  def convert(target_file)
    Open3.capture3("mpg123 -w #{target_file}.wav #{target_file}.mp3")
  end

  def play(target_file)
    Open3.capture3("aplay #{target_file}.wav")
  end
end

if $0 == __FILE__
  notifier = Notifier.new
  text = '間も無くミーティングが始まる時間です。'
  text = ARGV.first unless ARGV.empty?
  notifier.speech(text)
end
