TWEAK_NAME = ShowCase
ShowCase_OBJCC_FILES = Tweak.xmi
ShowCase_CFLAGS = -F$(SYSROOT)/System/Library/CoreServices

include theos/makefiles/common.mk
include theos/makefiles/tweak.mk

sync: stage
	rsync -z _/Library/MobileSubstrate/DynamicLibraries/* root@iphone:/Library/MobileSubstrate/DynamicLibraries/
	ssh root@iphone killall SpringBoard
