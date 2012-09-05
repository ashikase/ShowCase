TWEAK_NAME = ShowCase
ShowCase_OBJCC_FILES = Tweak.xmi
ShowCase_CFLAGS = -F$(SYSROOT)/System/Library/CoreServices

# Uncomment the following lines when compiling with self-built version of LLVM/Clang
#export GO_EASY_ON_ME = 1
#export SDKTARGET = arm-apple-darwin11
#export TARGET_CXX = clang -ccc-host-triple $(SDKTARGET)
#export TARGET_LD = $(SDKTARGET)-g++

include theos/makefiles/common.mk
include theos/makefiles/tweak.mk

sync: stage
	rsync -z _/Library/MobileSubstrate/DynamicLibraries/* root@iphone:/Library/MobileSubstrate/DynamicLibraries/
	ssh root@iphone killall SpringBoard
