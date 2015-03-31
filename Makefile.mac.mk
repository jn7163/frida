FRIDA := $(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))

PYTHON ?= /usr/bin/python2.7
PYTHON_NAME ?= $(shell basename $(PYTHON))

NODE ?= $(shell which node)
NODE_BIN_DIR := $(shell dirname $(NODE) 2>/dev/null)
NPM ?= $(NODE_BIN_DIR)/npm

tests ?= /

build_arch := $(shell releng/detect-arch.sh)

PREFIX ?= /usr

HELP_FUN = \
	my (%help, @sections); \
	while(<>) { \
		if (/^([\w-]+)\s*:.*\#\#(?:@([\w-]+))?\s(.*)$$/) { \
			$$section = $$2 // 'options'; \
			push @sections, $$section unless exists $$help{$$section}; \
			push @{$$help{$$section}}, [$$1, $$3]; \
		} \
	} \
	$$target_color = "\033[32m"; \
	$$variable_color = "\033[36m"; \
	$$reset_color = "\033[0m"; \
	print "\n"; \
	print "\033[31mUsage:$${reset_color} make -f Makefile.mac.mk $${target_color}TARGET$${reset_color} [$${variable_color}VARIABLE$${reset_color}=value]\n\n"; \
	print "Where $${target_color}TARGET$${reset_color} specifies one or more of:\n"; \
	print "\n"; \
	for (@sections) { \
		print "  /* $$_ */\n"; $$sep = " " x (20 - length $$_->[0]); \
		printf("  $${target_color}%-20s$${reset_color}    %s\n", $$_->[0], $$_->[1]) for @{$$help{$$_}}; \
		print "\n"; \
	} \
	print "And optionally also $${variable_color}VARIABLE$${reset_color} values:\n"; \
	print "  $${variable_color}PYTHON$${reset_color}                  Absolute path of Python interpreter including version suffix\n"; \
	print "  $${variable_color}NODE$${reset_color}                    Absolute path of Node.js binary\n"; \
	print "\n"; \
	print "For example:\n"; \
	print "  \$$ make -f Makefile.mac.mk $${target_color}python-mac $${variable_color}PYTHON$${reset_color}=/usr/local/bin/python3.4\n"; \
	print "  \$$ make -f Makefile.mac.mk $${target_color}node-mac $${variable_color}NODE$${reset_color}=/usr/local/bin/node\n"; \
	print "\n";

help:
	@LC_ALL=C perl -e '$(HELP_FUN)' $(MAKEFILE_LIST)


include releng/common.mk

distclean: clean-submodules
	rm -rf build/

clean: clean-submodules
	rm -f build/*.rc
	rm -f build/*.site
	rm -f build/*-stamp
	rm -rf build/frida-mac-i386
	rm -rf build/frida-mac-x86_64
	rm -rf build/frida-mac-universal
	rm -rf build/frida-ios-universal
	rm -rf build/frida-ios-arm
	rm -rf build/frida-ios-arm64
	rm -rf build/frida-android-i386
	rm -rf build/frida-android-arm
	rm -rf build/frida_stripped-mac-i386
	rm -rf build/frida_stripped-mac-x86_64
	rm -rf build/frida_stripped-android-i386
	rm -rf build/frida_stripped-android-arm
	rm -rf build/tmp-mac-i386
	rm -rf build/tmp-mac-x86_64
	rm -rf build/tmp-mac-universal
	rm -rf build/tmp-ios-arm
	rm -rf build/tmp-ios-arm64
	rm -rf build/tmp-ios-universal
	rm -rf build/tmp-android-i386
	rm -rf build/tmp-android-arm
	rm -rf build/tmp_stripped-mac-x86_64
	rm -rf build/tmp_stripped-ios-arm
	rm -rf build/tmp_stripped-ios-arm64
	rm -rf build/tmp_stripped-android-i386
	rm -rf build/tmp_stripped-android-arm

clean-submodules:
	cd capstone && git clean -xfd
	cd frida-gum && git clean -xfd
	cd frida-core && git clean -xfd
	cd frida-python && git clean -xfd
	cd frida-node && git clean -xfd


build/frida-%/lib/pkgconfig/capstone.pc: build/frida-env-%.rc build/capstone-submodule-stamp
	. build/frida-env-$*.rc \
		&& export PACKAGE_TARNAME=capstone \
		&& . $$CONFIG_SITE \
		&& make -C capstone \
			PREFIX=$$frida_prefix \
			BUILDDIR=../build/tmp-$*/capstone \
			CAPSTONE_ARCHS="arm aarch64 x86" \
			CAPSTONE_SHARED=$$enable_shared \
			CAPSTONE_STATIC=$$enable_static \
			install


gum-mac: build/frida-mac-i386/lib/pkgconfig/frida-gum-1.0.pc build/frida-mac-x86_64/lib/pkgconfig/frida-gum-1.0.pc ##@gum Build for Mac
gum-ios: build/frida-ios-arm/lib/pkgconfig/frida-gum-1.0.pc build/frida-ios-arm64/lib/pkgconfig/frida-gum-1.0.pc ##@gum Build for iOS
gum-android: build/frida-android-i386/lib/pkgconfig/frida-gum-1.0.pc build/frida-android-arm/lib/pkgconfig/frida-gum-1.0.pc ##@gum Build for Android

frida-gum/configure: build/frida-env-mac-$(build_arch).rc frida-gum/configure.ac
	. build/frida-env-mac-$(build_arch).rc && cd frida-gum && ./autogen.sh

build/tmp-%/frida-gum/Makefile: build/frida-env-%.rc frida-gum/configure build/frida-%/lib/pkgconfig/capstone.pc
	mkdir -p $(@D)
	. build/frida-env-$*.rc && cd $(@D) && ../../../frida-gum/configure

build/frida-%/lib/pkgconfig/frida-gum-1.0.pc: build/tmp-%/frida-gum/Makefile build/frida-gum-submodule-stamp
	@$(call ensure_relink,frida-gum/gum/gum.c,build/tmp-$*/frida-gum/gum/libfrida_gum_la-gum.lo)
	. build/frida-env-$*.rc && make -C build/tmp-$*/frida-gum install
	@touch -c $@

check-gum-mac: build/frida-mac-i386/lib/pkgconfig/frida-gum-1.0.pc build/frida-mac-x86_64/lib/pkgconfig/frida-gum-1.0.pc ##@gum Run tests for Mac
	build/tmp-mac-i386/frida-gum/tests/gum-tests -p $(tests)
	build/tmp-mac-x86_64/frida-gum/tests/gum-tests -p $(tests)


core-mac: build/frida-mac-i386/lib/pkgconfig/frida-core-1.0.pc build/frida-mac-x86_64/lib/pkgconfig/frida-core-1.0.pc ##@core Build for Mac
core-ios: build/frida-ios-arm/lib/pkgconfig/frida-core-1.0.pc build/frida-ios-arm64/lib/pkgconfig/frida-core-1.0.pc ##@core Build for iOS
core-android: build/frida-android-i386/lib/pkgconfig/frida-core-1.0.pc build/frida-android-arm/lib/pkgconfig/frida-core-1.0.pc ##@core Build for Android

frida-core/configure: build/frida-env-mac-$(build_arch).rc frida-core/configure.ac
	. build/frida-env-mac-$(build_arch).rc && cd frida-core && ./autogen.sh

build/tmp-%/frida-core/Makefile: build/frida-env-%.rc frida-core/configure build/frida-%/lib/pkgconfig/frida-gum-1.0.pc
	mkdir -p $(@D)
	. build/frida-env-$*.rc && cd $(@D) && ../../../frida-core/configure

build/tmp-%/frida-core/tools/resource-compiler: build/tmp-%/frida-core/Makefile build/frida-core-submodule-stamp
	@$(call ensure_relink,frida-core/tools/resource-compiler.c,build/tmp-$*/frida-core/tools/frida_resource_compiler-resource-compiler.o)
	. build/frida-env-$*.rc && make -C build/tmp-$*/frida-core/tools
	@touch -c $@

build/tmp-%/frida-core/lib/agent/libfrida-agent.la: build/tmp-%/frida-core/Makefile build/frida-core-submodule-stamp
	@$(call ensure_relink,frida-core/lib/agent/agent.c,build/tmp-$*/frida-core/lib/agent/libfrida_agent_la-agent.lo)
	. build/frida-env-$*.rc && make -C build/tmp-$*/frida-core/lib
	@touch -c $@

build/tmp-mac-universal/frida-core/lib/agent/.libs/libfrida-agent.dylib: build/tmp-mac-i386/frida-core/lib/agent/libfrida-agent.la build/tmp-mac-x86_64/frida-core/lib/agent/libfrida-agent.la
	mkdir -p $(@D)
	cp build/tmp-mac-i386/frida-core/lib/agent/.libs/libfrida-agent.dylib $(@D)/libfrida-agent-32.dylib
	cp build/tmp-mac-x86_64/frida-core/lib/agent/.libs/libfrida-agent.dylib $(@D)/libfrida-agent-64.dylib
	. build/frida-env-mac-$(build_arch).rc \
		&& $$STRIP -Sx $(@D)/libfrida-agent-32.dylib $(@D)/libfrida-agent-64.dylib \
		&& $$LIPO $(@D)/libfrida-agent-32.dylib $(@D)/libfrida-agent-64.dylib -create -output $@
build/tmp-ios-universal/frida-core/lib/agent/.libs/libfrida-agent.dylib: build/tmp-ios-arm/frida-core/lib/agent/libfrida-agent.la build/tmp-ios-arm64/frida-core/lib/agent/libfrida-agent.la
	mkdir -p $(@D)
	cp build/tmp-ios-arm/frida-core/lib/agent/.libs/libfrida-agent.dylib $(@D)/libfrida-agent-32.dylib
	cp build/tmp-ios-arm64/frida-core/lib/agent/.libs/libfrida-agent.dylib $(@D)/libfrida-agent-64.dylib
	. build/frida-env-ios-arm64.rc \
		&& $$STRIP -Sx $(@D)/libfrida-agent-32.dylib $(@D)/libfrida-agent-64.dylib \
		&& $$LIPO $(@D)/libfrida-agent-32.dylib $(@D)/libfrida-agent-64.dylib -create -output $@
build/tmp_stripped-%/frida-core/lib/agent/.libs/libfrida-agent.so: build/tmp-%/frida-core/lib/agent/libfrida-agent.la
	mkdir -p $(@D)
	cp build/tmp-$*/frida-core/lib/agent/.libs/libfrida-agent.so $@.tmp
	. build/frida-env-$*.rc && $$STRIP --strip-all $@.tmp
	mv $@.tmp $@

build/tmp-mac-%/frida-core/src/frida-helper: build/tmp-mac-%/frida-core/Makefile build/frida-core-submodule-stamp
	@$(call ensure_relink,frida-core/src/darwin/frida-helper-glue.c,build/tmp-mac-$*/frida-core/src/frida-helper-glue.lo)
	. build/frida-env-mac-$*.rc && make -C build/tmp-mac-$*/frida-core/src libfrida-helper-types.la frida-helper.stamp
	@touch -c $@
build/tmp-ios-%/frida-core/src/frida-helper: build/tmp-ios-%/frida-core/Makefile build/frida-core-submodule-stamp
	@$(call ensure_relink,frida-core/src/darwin/frida-helper-glue.c,build/tmp-ios-$*/frida-core/src/frida-helper-glue.lo)
	. build/frida-env-ios-$*.rc && make -C build/tmp-ios-$*/frida-core/src libfrida-helper-types.la frida-helper.stamp
	@touch -c $@
build/tmp-android-%/frida-core/src/frida-helper: build/tmp-android-%/frida-core/Makefile build/frida-core-submodule-stamp
	@$(call ensure_relink,frida-core/src/linux/frida-helper-glue.c,build/tmp-android-$*/frida-core/src/frida-helper-glue.lo)
	. build/frida-env-android-$*.rc && make -C build/tmp-android-$*/frida-core/src libfrida-helper-types.la frida-helper
	@touch -c $@
build/tmp_stripped-mac-x86_64/frida-core/src/frida-helper: build/tmp-mac-x86_64/frida-core/src/frida-helper
	@if [ -z "$$MAC_CERTID" ]; then echo "MAC_CERTID not set, see https://github.com/frida/frida#mac-and-ios"; exit 1; fi
	mkdir -p $(@D)
	cp $< $@.tmp
	. build/frida-env-mac-x86_64.rc \
		&& $$STRIP -Sx $@.tmp \
		&& $$CODESIGN -f -s "$$MAC_CERTID" -i "re.frida.Helper" $@.tmp
	mv $@.tmp $@
build/tmp_stripped-ios-arm/frida-core/src/frida-helper: build/tmp-ios-arm/frida-core/src/frida-helper
	@if [ -z "$$IOS_CERTID" ]; then echo "IOS_CERTID not set, see https://github.com/frida/frida#mac-and-ios"; exit 1; fi
	mkdir -p $(@D)
	cp $< $@.tmp
	. build/frida-env-ios-arm.rc \
		&& $$STRIP -Sx $@.tmp \
		&& $$CODESIGN -f -s "$$IOS_CERTID" --entitlements frida-core/src/darwin/frida-helper.xcent $@.tmp
	mv $@.tmp $@
build/tmp_stripped-ios-arm64/frida-core/src/frida-helper: build/tmp-ios-arm64/frida-core/src/frida-helper
	@if [ -z "$$IOS_CERTID" ]; then echo "IOS_CERTID not set, see https://github.com/frida/frida#mac-and-ios"; exit 1; fi
	mkdir -p $(@D)
	cp $< $@.tmp
	. build/frida-env-ios-arm64.rc \
		&& $$STRIP -Sx $@.tmp \
		&& $$CODESIGN -f -s "$$IOS_CERTID" --entitlements frida-core/src/darwin/frida-helper.xcent $@.tmp
	mv $@.tmp $@
build/tmp-ios-universal/frida-core/src/frida-helper: build/tmp_stripped-ios-arm/frida-core/src/frida-helper build/tmp_stripped-ios-arm64/frida-core/src/frida-helper
	@if [ -z "$$IOS_CERTID" ]; then echo "IOS_CERTID not set, see https://github.com/frida/frida#mac-and-ios"; exit 1; fi
	mkdir -p $(@D)
	. build/frida-env-ios-arm64.rc \
		&& $$LIPO $^ -create -output $@.tmp \
		&& $$CODESIGN -f -s "$$IOS_CERTID" --entitlements frida-core/src/darwin/frida-helper.xcent $@.tmp
	mv $@.tmp $@
build/tmp_stripped-android-%/frida-core/src/frida-helper: build/tmp-android-%/frida-core/src/frida-helper
	mkdir -p $(@D)
	cp $< $@.tmp
	. build/frida-env-android-$*.rc && $$STRIP --strip-all $@.tmp
	mv $@.tmp $@

build/frida-mac-%/lib/pkgconfig/frida-core-1.0.pc: build/tmp-mac-universal/frida-core/lib/agent/.libs/libfrida-agent.dylib build/tmp_stripped-mac-x86_64/frida-core/src/frida-helper build/tmp-mac-$(build_arch)/frida-core/tools/resource-compiler
	@$(call ensure_relink,frida-core/src/frida.c,build/tmp-mac-$*/frida-core/src/libfrida_core_la-frida.lo)
	. build/frida-env-mac-$*.rc \
		&& cd build/tmp-mac-$*/frida-core \
		&& make -C src install \
			RESOURCE_COMPILER="../../../../build/tmp-mac-$(build_arch)/frida-core/tools/resource-compiler --toolchain=apple" \
			AGENT=../../../../build/tmp-mac-universal/frida-core/lib/agent/.libs/libfrida-agent.dylib!frida-agent.dylib \
			HELPER=../../../../build/tmp_stripped-mac-x86_64/frida-core/src/frida-helper \
		&& make install-data-am
	@touch -c $@
build/frida-ios-arm/lib/pkgconfig/frida-core-1.0.pc: build/tmp-ios-universal/frida-core/lib/agent/.libs/libfrida-agent.dylib build/tmp-ios-universal/frida-core/src/frida-helper build/tmp-mac-$(build_arch)/frida-core/tools/resource-compiler
	@$(call ensure_relink,frida-core/src/frida.c,build/tmp-ios-arm/frida-core/src/libfrida_core_la-frida.lo)
	. build/frida-env-ios-arm.rc \
		&& cd build/tmp-ios-arm/frida-core \
		&& make -C src install \
			RESOURCE_COMPILER="../../../../build/tmp-mac-$(build_arch)/frida-core/tools/resource-compiler --toolchain=apple" \
			AGENT=../../../../build/tmp-ios-universal/frida-core/lib/agent/.libs/libfrida-agent.dylib!frida-agent.dylib \
			HELPER=../../../../build/tmp-ios-universal/frida-core/src/frida-helper \
		&& make install-data-am
	@touch -c $@
build/frida-ios-arm64/lib/pkgconfig/frida-core-1.0.pc: build/tmp-ios-universal/frida-core/lib/agent/.libs/libfrida-agent.dylib build/tmp-ios-universal/frida-core/src/frida-helper build/tmp-mac-$(build_arch)/frida-core/tools/resource-compiler
	@$(call ensure_relink,frida-core/src/frida.c,build/tmp-ios-arm64/frida-core/src/libfrida_core_la-frida.lo)
	. build/frida-env-ios-arm64.rc \
		&& cd build/tmp-ios-arm64/frida-core \
		&& make -C src install \
			RESOURCE_COMPILER="../../../../build/tmp-mac-$(build_arch)/frida-core/tools/resource-compiler --toolchain=apple" \
			AGENT=../../../../build/tmp-ios-universal/frida-core/lib/agent/.libs/libfrida-agent.dylib!frida-agent.dylib \
			HELPER=../../../../build/tmp_stripped-ios-arm64/frida-core/src/frida-helper \
		&& make install-data-am
	@touch -c $@
build/frida-android-i386/lib/pkgconfig/frida-core-1.0.pc: build/tmp_stripped-android-i386/frida-core/lib/agent/.libs/libfrida-agent.so build/tmp_stripped-android-i386/frida-core/src/frida-helper build/tmp-mac-$(build_arch)/frida-core/tools/resource-compiler
	@$(call ensure_relink,frida-core/src/frida.c,build/tmp-android-i386/frida-core/src/libfrida_core_la-frida.lo)
	. build/frida-env-android-i386.rc \
		&& cd build/tmp-android-i386/frida-core \
		&& make -C src install \
			RESOURCE_COMPILER="../../../../build/tmp-mac-$(build_arch)/frida-core/tools/resource-compiler --toolchain=gnu" \
			AGENT32=../../../../build/tmp_stripped-android-i386/frida-core/lib/agent/.libs/libfrida-agent.so!frida-agent-32.so \
			HELPER32=../../../../build/tmp_stripped-android-i386/frida-core/src/frida-helper!frida-helper-32 \
		&& make install-data-am
	@touch -c $@
build/frida-android-arm/lib/pkgconfig/frida-core-1.0.pc: build/tmp_stripped-android-arm/frida-core/lib/agent/.libs/libfrida-agent.so build/tmp_stripped-android-arm/frida-core/src/frida-helper build/tmp-mac-$(build_arch)/frida-core/tools/resource-compiler
	@$(call ensure_relink,frida-core/src/frida.c,build/tmp-android-arm/frida-core/src/libfrida_core_la-frida.lo)
	. build/frida-env-android-arm.rc \
		&& cd build/tmp-android-arm/frida-core \
		&& make -C src install \
			RESOURCE_COMPILER="../../../../build/tmp-mac-$(build_arch)/frida-core/tools/resource-compiler --toolchain=gnu" \
			AGENT32=../../../../build/tmp_stripped-android-arm/frida-core/lib/agent/.libs/libfrida-agent.so!frida-agent-32.so \
			HELPER32=../../../../build/tmp_stripped-android-arm/frida-core/src/frida-helper!frida-helper-32 \
		&& make install-data-am
	@touch -c $@

build/tmp-%/frida-core/tests/frida-tests: build/frida-%/lib/pkgconfig/frida-core-1.0.pc
	@$(call ensure_relink,frida-core/tests/main.c,build/tmp-$*/frida-core/tests/main.o)
	@$(call ensure_relink,frida-core/tests/inject-victim.c,build/tmp-$*/frida-core/tests/inject-victim.o)
	@$(call ensure_relink,frida-core/tests/inject-attacker.c,build/tmp-$*/frida-core/tests/inject-attacker.o)
	. build/frida-env-$*.rc && make -C build/tmp-$*/frida-core/tests
	@touch -c $@

check-core-mac: build/tmp-mac-i386/frida-core/tests/frida-tests build/tmp-mac-x86_64/frida-core/tests/frida-tests ##@core Run tests for Mac
	build/tmp-mac-i386/frida-core/tests/frida-tests
	build/tmp-mac-x86_64/frida-core/tests/frida-tests


server-mac: build/frida-mac-universal/bin/frida-server ##@server Build for Mac
server-ios: build/frida-ios-universal/bin/frida-server ##@server Build for iOS
server-android: build/frida_stripped-android-i386/bin/frida-server build/frida_stripped-android-arm/bin/frida-server ##@server Build for Android

build/frida-mac-universal/bin/frida-server: build/frida-mac-i386/bin/frida-server build/frida-mac-x86_64/bin/frida-server
	mkdir -p $(@D)
	cp build/frida-mac-i386/bin/frida-server $(@D)/frida-server-32
	cp build/frida-mac-x86_64/bin/frida-server $(@D)/frida-server-64
	. build/frida-env-mac-$(build_arch).rc \
		&& $$STRIP -Sx $(@D)/frida-server-32 $(@D)/frida-server-64 \
		&& $$LIPO $(@D)/frida-server-32 $(@D)/frida-server-64 -create -output $@
	$(RM) $(@D)/frida-server-32 $(@D)/frida-server-64
build/frida-ios-universal/bin/frida-server: build/frida-ios-arm/bin/frida-server build/frida-ios-arm64/bin/frida-server
	mkdir -p $(@D)
	cp build/frida-ios-arm/bin/frida-server $(@D)/frida-server-32
	cp build/frida-ios-arm64/bin/frida-server $(@D)/frida-server-64
	. build/frida-env-ios-arm64.rc \
		&& $$STRIP -Sx $(@D)/frida-server-32 $(@D)/frida-server-64 \
		&& $$LIPO $(@D)/frida-server-32 $(@D)/frida-server-64 -create -output $@
	$(RM) $(@D)/frida-server-32 $(@D)/frida-server-64
build/frida_stripped-android-i386/bin/frida-server: build/frida-android-i386/bin/frida-server
	mkdir -p $(@D)
	cp $< $@.tmp
	. build/frida-env-android-i386.rc && $$STRIP --strip-all $@.tmp
	mv $@.tmp $@
build/frida_stripped-android-arm/bin/frida-server: build/frida-android-arm/bin/frida-server
	mkdir -p $(@D)
	cp $< $@.tmp
	. build/frida-env-android-arm.rc && $$STRIP --strip-all $@.tmp
	mv $@.tmp $@
build/frida-%/bin/frida-server: build/frida-%/lib/pkgconfig/frida-core-1.0.pc
	@$(call ensure_relink,frida-core/server/server.c,build/tmp-$*/frida-core/server/frida_server-server.o)
	. build/frida-env-$*.rc && make -C build/tmp-$*/frida-core/server install
	@touch -c $@


python-mac: build/frida-mac-universal/lib/$(PYTHON_NAME)/site-packages/frida build/frida-mac-universal/lib/$(PYTHON_NAME)/site-packages/_frida.so build/frida-mac-universal/bin/frida-repl ##@bindings Build Python bindings for Mac

frida-python/configure: build/frida-env-mac-$(build_arch).rc frida-python/configure.ac
	. build/frida-env-mac-$(build_arch).rc && cd frida-python && ./autogen.sh

build/tmp-%/frida-$(PYTHON_NAME)/Makefile: build/frida-env-%.rc frida-python/configure build/frida-%/lib/pkgconfig/frida-core-1.0.pc
	mkdir -p $(@D)
	. build/frida-env-$*.rc && cd $(@D) && PYTHON=$(PYTHON) ../../../frida-python/configure

build/tmp-%/frida-$(PYTHON_NAME)/src/_frida.la: build/tmp-%/frida-$(PYTHON_NAME)/Makefile build/frida-python-submodule-stamp
	. build/frida-env-$*.rc && cd build/tmp-$*/frida-$(PYTHON_NAME) && make
	@$(call ensure_relink,frida-python/src/_frida.c,build/tmp-$*/frida-$(PYTHON_NAME)/src/_frida.lo)
	. build/frida-env-$*.rc && cd build/tmp-$*/frida-$(PYTHON_NAME) && make install
	@touch -c $@

build/frida-mac-universal/lib/$(PYTHON_NAME)/site-packages/frida: build/tmp-mac-x86_64/frida-$(PYTHON_NAME)/src/_frida.la
	rm -rf $@
	mkdir -p $(@D)
	cp -a build/frida-mac-x86_64/lib/$(PYTHON_NAME)/site-packages/frida $@
	@touch $@

build/frida-mac-universal/lib/$(PYTHON_NAME)/site-packages/_frida.so: build/tmp-mac-i386/frida-$(PYTHON_NAME)/src/_frida.la build/tmp-mac-x86_64/frida-$(PYTHON_NAME)/src/_frida.la
	mkdir -p $(@D)
	cp build/tmp-mac-i386/frida-$(PYTHON_NAME)/src/.libs/_frida.so $(@D)/_frida-32.so
	cp build/tmp-mac-x86_64/frida-$(PYTHON_NAME)/src/.libs/_frida.so $(@D)/_frida-64.so
	. build/frida-env-mac-$(build_arch).rc \
		&& $$STRIP -Sx $(@D)/_frida-32.so $(@D)/_frida-64.so \
		&& $$LIPO $(@D)/_frida-32.so $(@D)/_frida-64.so -create -output $@
	rm $(@D)/_frida-32.so $(@D)/_frida-64.so

build/frida-mac-universal/bin/frida-%: build/tmp-mac-x86_64/frida-$(PYTHON_NAME)/src/_frida.la
	mkdir -p build/frida-mac-universal/bin \
		&& cp -r build/frida-mac-x86_64/bin/ build/frida-mac-universal/bin

check-python-mac: python-mac ##@bindings Test Python bindings for Mac
	export PYTHONPATH="$(shell pwd)/build/frida-mac-universal/lib/$(PYTHON_NAME)/site-packages" \
		&& cd frida-python \
		&& if $(PYTHON) -c "import sys; v = sys.version_info; can_execute_modules = v[0] > 2 or (v[0] == 2 and v[1] >= 7); sys.exit(0 if can_execute_modules else 1)"; then \
			$(PYTHON) -m unittest discover; \
		else \
			unit2 discover; \
		fi

install-python-mac: python-mac ##@bindings Install Python bindings for Mac
	sitepackages=`$(PYTHON) -c 'import site; print(site.getsitepackages()[0])'` \
		&& cp -r "build/frida-mac-universal/lib/$(PYTHON_NAME)/site-packages/" "$$sitepackages"

uninstall-python-mac: ##@bindings Uninstall Python bindings for mac
	cd `$(PYTHON) -c 'import site; print(site.getsitepackages()[0])'` \
		&& rm -rf _frida.so frida


node-mac: build/frida_stripped-mac-$(build_arch)/lib/node_modules/frida build/frida-node-submodule-stamp ##@bindings Build Node.js bindings for Mac

build/frida_stripped-%/lib/node_modules/frida: build/frida-%/lib/pkgconfig/frida-core-1.0.pc build/frida-node-submodule-stamp
	export PATH=$(NODE_BIN_DIR):$$PATH FRIDA=$(FRIDA) \
		&& cd frida-node \
		&& rm -rf frida-0.0.0.tgz build lib/binding node_modules \
		&& $(NPM) install --build-from-source \
		&& $(NPM) pack \
		&& rm -rf ../$@/ ../$@.tmp/ \
		&& mkdir -p ../$@.tmp/ \
		&& tar -C ../$@.tmp/ --strip-components 1 -x -f frida-0.0.0.tgz \
		&& rm frida-0.0.0.tgz \
		&& mv lib/binding ../$@.tmp/lib/ \
		&& mv node_modules ../$@.tmp/ \
		&& . build/frida-env-mac-$(build_arch).rc && $$STRIP -Sx ../$@.tmp/lib/binding/Release/node-*/frida_binding.node \
		&& mv ../$@.tmp ../$@

check-node-mac: build/frida_stripped-mac-$(build_arch)/lib/node_modules/frida ##@bindings Test Node.js bindings for Mac
	cd $< && $(NODE) --expose-gc node_modules/mocha/bin/_mocha


install-mac: install-python-mac ##@utilities Install frida utilities (frida-{discover,ps,repl,trace})
	@$(PYTHON) -measy_install colorama \
		&& for b in "build/frida-mac-universal/bin"/*; do \
			n=`basename $$b`; \
			p="$(PREFIX)/bin/$$n"; \
			grep -v 'sys.path.insert' "$$b" > "$$p"; \
			chmod +x "$$p"; \
		done

uninstall-mac: ##@utilities Uninstall frida utilities
	@for c in discover ps repl trace; do \
		n=frida-"$$c"; \
		if which "$$n" &> /dev/null; then \
			p=`which "$$n"`; \
			rm -f "$$p"; \
		fi \
	done

.PHONY: \
	distclean clean clean-submodules git-submodules git-submodule-stamps \
	capstone-update-submodule-stamp \
	gum-mac gum-ios gum-android check-gum-mac frida-gum-update-submodule-stamp \
	core-mac core-ios core-android check-core-mac frida-core-update-submodule-stamp \
	server-mac server-ios server-android \
	python-mac check-python-mac install-python-mac uninstall-python-mac frida-python-update-submodule-stamp \
	node-mac check-node-mac frida-node-update-submodule-stamp \
	install-mac uninstall-mac
.SECONDARY:
