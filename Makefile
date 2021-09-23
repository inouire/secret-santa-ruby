.PHONY: install send-real send-override try

install:
	bundle install

try:
	bundle exec ruby santa.rb send

send-override:
	bundle exec ruby santa.rb send --for-real --email fake@fake.fr

send-real:
	bundle exec ruby santa.rb send --for-real

