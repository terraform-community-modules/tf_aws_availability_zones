.PHONEY: all

all: variables.tf.json

variables.tf.json:
	ruby getvariables.rb

iam_variables:
	        ruby getvariables.rb -i $(iam_profile) -a $(account)

clean:
	rm -f variables.tf.json

