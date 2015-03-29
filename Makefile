.PHONEY: all

all: variables.tf.json

variables.tf.json:
	ruby getvariables.rb

clean:
	rm -f variables.tf.json

