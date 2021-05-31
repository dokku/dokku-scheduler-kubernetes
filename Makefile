HARDWARE = $(shell uname -m)
SYSTEM_NAME  = $(shell uname -s | tr '[:upper:]' '[:lower:]')
SHFMT_VERSION = 3.0.2
XUNIT_TO_GITHUB_VERSION = 0.3.0
XUNIT_READER_VERSION = 0.1.0
DOKKU_SSH_PORT ?= 22

bats:
ifeq ($(SYSTEM_NAME),darwin)
ifneq ($(shell bats --version >/dev/null 2>&1 ; echo $$?),0)
	brew install bats-core
endif
else
	git clone https://github.com/josegonzalez/bats-core.git /tmp/bats
	cd /tmp/bats && sudo ./install.sh /usr/local
	rm -rf /tmp/bats
endif

shellcheck:
ifneq ($(shell shellcheck --version >/dev/null 2>&1 ; echo $$?),0)
ifeq ($(SYSTEM_NAME),darwin)
	brew install shellcheck
else
	sudo add-apt-repository 'deb http://archive.ubuntu.com/ubuntu trusty-backports main restricted universe multiverse'
	sudo rm -rf /var/lib/apt/lists/* && sudo apt-get clean
	sudo apt-get update -qq && sudo apt-get install -qq -y shellcheck
endif
endif

shfmt:
ifneq ($(shell shfmt --version >/dev/null 2>&1 ; echo $$?),0)
ifeq ($(shfmt),Darwin)
	brew install shfmt
else
	wget -qO /tmp/shfmt https://github.com/mvdan/sh/releases/download/v$(SHFMT_VERSION)/shfmt_v$(SHFMT_VERSION)_linux_amd64
	chmod +x /tmp/shfmt
	sudo mv /tmp/shfmt /usr/local/bin/shfmt
endif
endif

readlink:
ifeq ($(shell uname),Darwin)
ifeq ($(shell greadlink > /dev/null 2>&1 ; echo $$?),127)
	brew install coreutils
endif
	ln -nfs `which greadlink` tests/bin/readlink
endif

ci-dependencies: shellcheck bats readlink

lint-setup:
	@mkdir -p tmp/test-results/shellcheck tmp/shellcheck
	@find . -not -path '*/\.*' -type f | xargs file | grep text | awk -F ':' '{ print $$1 }' | xargs head -n1 | egrep -B1 "bash" | grep "==>" | awk '{ print $$2 }' > tmp/shellcheck/test-files
	@cat tests/shellcheck-exclude | sed -n -e '/^# SC/p' | cut -d' ' -f2 | paste -d, -s - > tmp/shellcheck/exclude

lint: lint-setup
	# these are disabled due to their expansive existence in the codebase. we should clean it up though
	@cat tests/shellcheck-exclude | sed -n -e '/^# SC/p'
	@echo linting...
	@cat tmp/shellcheck/test-files | xargs shellcheck -e $(shell cat tmp/shellcheck/exclude) | tests/shellcheck-to-junit --output tmp/test-results/shellcheck/results.xml --files tmp/shellcheck/test-files --exclude $(shell cat tmp/shellcheck/exclude)

unit-tests:
	@echo running unit tests...
	@mkdir -p tmp/test-results/bats
	@cd tests && echo "executing tests: $(shell cd tests ; ls *.bats | xargs)"
	cd tests && bats --formatter bats-format-junit -e -T -o ../tmp/test-results/bats *.bats

tmp/xunit-reader:
	mkdir -p tmp
	curl -o tmp/xunit-reader.tgz -sL https://github.com/josegonzalez/go-xunit-reader/releases/download/v$(XUNIT_READER_VERSION)/xunit-reader_$(XUNIT_READER_VERSION)_$(SYSTEM_NAME)_$(HARDWARE).tgz
	tar xf tmp/xunit-reader.tgz -C tmp
	chmod +x tmp/xunit-reader

tmp/xunit-to-github:
	mkdir -p tmp
	curl -o tmp/xunit-to-github.tgz -sL https://github.com/josegonzalez/go-xunit-to-github/releases/download/v$(XUNIT_TO_GITHUB_VERSION)/xunit-to-github_$(XUNIT_TO_GITHUB_VERSION)_$(SYSTEM_NAME)_$(HARDWARE).tgz
	tar xf tmp/xunit-to-github.tgz -C tmp
	chmod +x tmp/xunit-to-github

setup:
	bash tests/setup.sh
	$(MAKE) ci-dependencies

test: lint unit-tests

report: tmp/xunit-reader tmp/xunit-to-github
	tmp/xunit-reader -p 'tmp/test-results/bats/*.xml'
	tmp/xunit-reader -p 'tmp/test-results/shellcheck/*.xml'
ifdef TRAVIS_REPO_SLUG
ifdef GITHUB_ACCESS_TOKEN
ifneq ($(TRAVIS_PULL_REQUEST),false)
	tmp/xunit-to-github --skip-ok --job-url "$(TRAVIS_JOB_WEB_URL)" --pull-request-id "$(TRAVIS_PULL_REQUEST)" --repository-slug "$(TRAVIS_REPO_SLUG)" --title "DOKKU_VERSION=$(DOKKU_VERSION)" tmp/test-results/bats tmp/test-results/shellcheck
endif
endif
endif

.PHONY: clean
clean:
	rm -f README.md

.PHONY: generate
generate: clean README.md

.PHONY: README.md
README.md:
	bin/generate

setup-deploy-tests:
ifdef ENABLE_DOKKU_TRACE
	echo "-----> Enable dokku trace"
	dokku trace:on
endif
	@echo "Setting dokku.me in /etc/hosts"
	sudo /bin/bash -c "[[ `ping -c1 dokku.me >/dev/null 2>&1; echo $$?` -eq 0 ]] || echo \"127.0.0.1  dokku.me *.dokku.me www.test.app.dokku.me\" >> /etc/hosts"

	@echo "-----> Generating keypair..."
	mkdir -p /root/.ssh
	rm -f /root/.ssh/dokku_test_rsa*
	echo -e  "y\n" | ssh-keygen -f /root/.ssh/dokku_test_rsa -t rsa -N ''
	chmod 700 /root/.ssh
	chmod 600 /root/.ssh/dokku_test_rsa
	chmod 644 /root/.ssh/dokku_test_rsa.pub

	@echo "-----> Setting up ssh config..."
ifneq ($(shell ls /root/.ssh/config >/dev/null 2>&1 ; echo $$?),0)
	echo "Host dokku.me \\r\\n Port $(DOKKU_SSH_PORT) \\r\\n RequestTTY yes \\r\\n IdentityFile /root/.ssh/dokku_test_rsa" >> /root/.ssh/config
	echo "Host 127.0.0.1 \\r\\n Port 22333 \\r\\n RequestTTY yes \\r\\n IdentityFile /root/.ssh/dokku_test_rsa" >> /root/.ssh/config
else ifeq ($(shell grep dokku.me /root/.ssh/config),)
	echo "Host dokku.me \\r\\n Port $(DOKKU_SSH_PORT) \\r\\n RequestTTY yes \\r\\n IdentityFile /root/.ssh/dokku_test_rsa" >> /root/.ssh/config
	echo "Host 127.0.0.1 \\r\\n Port 22333 \\r\\n RequestTTY yes \\r\\n IdentityFile /root/.ssh/dokku_test_rsa" >> /root/.ssh/config
else
	sed --in-place 's/Port 22 \r/Port $(DOKKU_SSH_PORT) \r/g' /root/.ssh/config
	cat /root/.ssh/config
endif

ifneq ($(wildcard /etc/ssh/sshd_config),)
	sed --in-place "s/^#Port 22$\/Port 22/g" /etc/ssh/sshd_config
ifeq ($(shell grep 22333 /etc/ssh/sshd_config),)
	sed --in-place "s:^Port 22:Port 22 \\nPort 22333:g" /etc/ssh/sshd_config
endif
	service ssh restart
endif

	@echo "-----> Installing SSH public key..."
	echo "" > /home/dokku/.ssh/authorized_keys
	sudo sshcommand acl-remove dokku test
	cat /root/.ssh/dokku_test_rsa.pub | sudo sshcommand acl-add dokku test
	chmod 700 /home/dokku/.ssh
	chmod 600 /home/dokku/.ssh/authorized_keys

ifeq ($(shell grep dokku.me /home/dokku/VHOST 2>/dev/null),)
	@echo "-----> Setting default VHOST to dokku.me..."
	echo "dokku.me" > /home/dokku/VHOST
endif
ifeq ($(DOKKU_SSH_PORT), 22)
	$(MAKE) prime-ssh-known-hosts
endif

prime-ssh-known-hosts:
	@echo "-----> Intitial SSH connection to populate known_hosts..."
	@echo "=====> SSH dokku.me"
	ssh -o StrictHostKeyChecking=no dokku@dokku.me help >/dev/null
	@echo "=====> SSH 127.0.0.1"
	ssh -o StrictHostKeyChecking=no dokku@127.0.0.1 help >/dev/null
