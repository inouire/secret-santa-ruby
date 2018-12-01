require 'byebug'
require 'colorize'
require 'mail'
require "thor"
require 'yaml'

# The Elf class, that stores information about people participating
class Elf
  attr_accessor :name
  attr_accessor :email
  attr_accessor :target

  def initialize(name, email)
    @name  = name
    @email = email
  end

  def to_s
    name.green + " --> " + target.name.green + " (mail will be sent to " + email.white.on_blue + ")"
  end
end

class SecretSantaCLI < Thor

  desc "send [config_file.yml]", "Send mail to participant of secret santa. Default config file is elves.yml"
  option :email, :banner => "override recipient emails with this email"
  option :for_real, :type => :boolean, :banner => "send emails for real (default mode is to not send anything)"
  def send(elves_file = 'elves.yml')
    # Parse args
    puts "Hello, this is santa !".white.on_cyan
    override_email = options[:email]
    send_emails    = options[:for_real]

    # Load config file
    config = YAML.load_file(elves_file)

    # Build elves list
    elves = config['elves'].map do |props|
      Elf.new(props['name'], override_email || props['email'])
    end.shuffle!
    puts elves.size.to_s.yellow + " elves participate in the project"

    # Attribute targets
    elves.each_with_index do |elf, k|
      if k < elves.size - 1
        elf.target = elves[k+1]
      else
        elf.target = elves[0]
      end
    end

    # Recap targets and ask for confirmation
    elves.each { |elf| puts elf.to_s }

    # Abort sending unless in real mode
    if !send_emails
      puts "No email sent because in dry mode.".white.on_red
      puts "Use --for-real option to send them. Use --email plop@stuff.com option to override recipient emails.".yellow
      exit 1
    end

    # Ask for confirmation before sending emails
    ARGV.clear
    puts "Are you OK with that? Emails will be sent (y/n)".white.on_cyan
    answer = gets.strip
    exit if answer.downcase != 'y'

    # Configure mail delivery
    Mail.defaults do
      delivery_method config['transport']['method'].to_sym,
        config['transport']['args'].map { |key, value| [key.to_sym, value] }.to_h
    end

    # Send emails
    elves.each do |elf|
      puts "Sending email for #{elf.email}...".yellow
      mail = build_email(elf, config)
      mail.deliver!
    end
  end

  no_commands do
    def build_email(elf, config)
      from_email = config.dig('transport', 'from')

      custom_subject = resolve_placeholders(config.dig('message', 'subject'), elf)

      custom_body = config.dig('message', 'body').map do |line|
        resolve_placeholders(line, elf)
      end.join("\n")


      Mail.new do
        from    from_email
        to      elf.email
        subject custom_subject
        body    custom_body
      end
    end

    def resolve_placeholders(blob, elf)
      blob.gsub(/{{\s*name\s*}}/, elf.name)
        .gsub(/{{\s*target_name\s*}}/, elf.target.name)
    end
  end

end

SecretSantaCLI.start(ARGV)
