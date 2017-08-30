require 'bundler/setup'
require 'open3'
require 'digest/md5'

require 'java'
require 'aws-java-sdk-1.11.185.jar'
require 'commons-logging-1.2.jar'
require 'commons-codec-1.9.jar'
require 'httpcore-4.4.6.jar'
require 'httpclient-4.5.3.jar'
require 'jackson-core-2.9.0.jar'
require 'jackson-databind-2.9.0.jar'
require 'jackson-annotations-2.9.0.jar'

java_import 'java.lang.System'
java_import 'java.nio.file.Files'
java_import 'java.nio.file.StandardCopyOption'
java_import 'com.amazonaws.auth.BasicAWSCredentials'
java_import 'com.amazonaws.auth.AWSStaticCredentialsProvider'
java_import 'com.amazonaws.services.polly.AmazonPollyClientBuilder'
java_import 'com.amazonaws.services.polly.model.SynthesizeSpeechRequest'

class Notifier
  VOICE_DIR = '/work/schedule_reminder/voices'

  REGION            = 'us-east-1'
  ACCESS_KEY_ID     = ENV['ACCESS_KEY_ID']
  SECRET_ACCESS_KEY = ENV['SECRET_ACCESS_KEY']
  VOICE_ID_JP       = 'Mizuki'

  def initialize
    aws_credentials = BasicAWSCredentials.new(ACCESS_KEY_ID, SECRET_ACCESS_KEY)
    aws_credentials_provider = AWSStaticCredentialsProvider.new(aws_credentials)
    @client = AmazonPollyClientBuilder.standard.withCredentials(aws_credentials_provider).withRegion(REGION).build
  end

  def speech(text)
    text_hash = Digest::MD5.hexdigest(text)
    target_file = "#{VOICE_DIR}/#{text_hash}"

    synthesize(text, target_file)
    convert(target_file)
    play(target_file)
  end

  def synthesize(text, target_file)
    speech_request = SynthesizeSpeechRequest.new.withText(text).withVoiceId(VOICE_ID_JP).withOutputFormat('mp3')
    speech_result = @client.synthesizeSpeech(speech_request)
    file = java.io.File.new("#{target_file}.mp3")
    Files.copy(speech_result.getAudioStream, file.toPath, StandardCopyOption.valueOf('REPLACE_EXISTING'))
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
  System.out.println('Done')
end
