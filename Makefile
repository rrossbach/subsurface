VERSION=3.0.2

CC=gcc
CFLAGS=-Wall -Wno-pointer-sign -g $(CLCFLAGS) -DGSEAL_ENABLE
CXX=g++
CXXFLAGS=-Wall -g $(CLCFLAGS) -DQT_NO_KEYWORDS
INSTALL=install
PKGCONFIG=pkg-config
XML2CONFIG=xml2-config
XSLCONFIG=xslt-config
QMAKE=qmake
MOC=moc
UIC=uic

# these locations seem to work for SuSE and Fedora
# prefix = $(HOME)
prefix = $(DESTDIR)/usr
BINDIR = $(prefix)/bin
DATADIR = $(prefix)/share
DESKTOPDIR = $(DATADIR)/applications
ICONPATH = $(DATADIR)/icons/hicolor
ICONDIR = $(ICONPATH)/scalable/apps
MANDIR = $(DATADIR)/man/man1
XSLTDIR = $(DATADIR)/subsurface/xslt
gtk_update_icon_cache = gtk-update-icon-cache -f -t $(ICONPATH)

NAME = subsurface
ICONFILE = $(NAME)-icon.svg
DESKTOPFILE = $(NAME).desktop
MANFILES = $(NAME).1
XSLTFILES = xslt/*.xslt

VERSION_FILE = version.h
# There's only one line in $(VERSION_FILE); use the shell builtin `read'
STORED_VERSION_STRING = \
	$(subst ",,$(shell [ ! -r $(VERSION_FILE) ] || \
			   read ignore ignore v <$(VERSION_FILE) && echo $$v))
#" workaround editor syntax highlighting quirk

UNAME := $(shell $(CC) -dumpmachine 2>&1 | grep -E -o "linux|darwin|win|gnu|kfreebsd")
GET_VERSION = ./scripts/get-version
VERSION_STRING := $(shell $(GET_VERSION) linux || echo "v$(VERSION)")
# Mac Info.plist style with three numbers 1.2.3
CFBUNDLEVERSION_STRING := $(shell $(GET_VERSION) darwin $(VERSION_STRING) || \
	echo "$(VERSION).0")
# Windows .nsi style with four numbers 1.2.3.4
PRODVERSION_STRING := $(shell $(GET_VERSION) win $(VERSION_STRING) || \
	echo "$(VERSION).0.0")

# find libdivecomputer
# First deal with the cross compile environment and with Mac.
# For the native case, Linus doesn't want to trust pkg-config given
# how young libdivecomputer still is - so we check the typical
# subdirectories of /usr/local and /usr and then we give up. You can
# override by simply setting it here
#
ifeq ($(CC), i686-w64-mingw32-gcc)
# ok, we are cross building for Windows
	LIBDIVECOMPUTERINCLUDES = $(shell $(PKGCONFIG) --cflags libdivecomputer)
	LIBDIVECOMPUTERARCHIVE = $(shell $(PKGCONFIG) --libs libdivecomputer)
	RESFILE = packaging/windows/subsurface.res
	LDFLAGS += -Wl,-subsystem,windows
	LIBWINSOCK = -lwsock32
else ifeq ($(UNAME), darwin)
	LIBDIVECOMPUTERINCLUDES = $(shell $(PKGCONFIG) --cflags libdivecomputer)
	LIBDIVECOMPUTERARCHIVE = $(shell $(PKGCONFIG) --libs libdivecomputer)
else
libdc-local := $(wildcard /usr/local/lib/libdivecomputer.a)
libdc-local64 := $(wildcard /usr/local/lib64/libdivecomputer.a)
libdc-usr := $(wildcard /usr/lib/libdivecomputer.a)
libdc-usr64 := $(wildcard /usr/lib64/libdivecomputer.a)

ifneq ($(LIBDCDEVEL),)
	LIBDIVECOMPUTERDIR = ../libdivecomputer
	LIBDIVECOMPUTERINCLUDES = -I$(LIBDIVECOMPUTERDIR)/include
	LIBDIVECOMPUTERARCHIVE = $(LIBDIVECOMPUTERDIR)/src/.libs/libdivecomputer.a
else ifneq ($(strip $(libdc-local)),)
	LIBDIVECOMPUTERDIR = /usr/local
	LIBDIVECOMPUTERINCLUDES = -I$(LIBDIVECOMPUTERDIR)/include
	LIBDIVECOMPUTERARCHIVE = $(LIBDIVECOMPUTERDIR)/lib/libdivecomputer.a
else ifneq ($(strip $(libdc-local64)),)
	LIBDIVECOMPUTERDIR = /usr/local
	LIBDIVECOMPUTERINCLUDES = -I$(LIBDIVECOMPUTERDIR)/include
	LIBDIVECOMPUTERARCHIVE = $(LIBDIVECOMPUTERDIR)/lib64/libdivecomputer.a
else ifneq ($(strip $(libdc-usr)),)
	LIBDIVECOMPUTERDIR = /usr
	LIBDIVECOMPUTERINCLUDES = -I$(LIBDIVECOMPUTERDIR)/include
	LIBDIVECOMPUTERARCHIVE = $(LIBDIVECOMPUTERDIR)/lib/libdivecomputer.a
else ifneq ($(strip $(libdc-usr64)),)
	LIBDIVECOMPUTERDIR = /usr
	LIBDIVECOMPUTERINCLUDES = -I$(LIBDIVECOMPUTERDIR)/include
	LIBDIVECOMPUTERARCHIVE = $(LIBDIVECOMPUTERDIR)/lib64/libdivecomputer.a
else
$(error Cannot find libdivecomputer - please edit Makefile)
endif
endif

# Libusb-1.0 is only required if libdivecomputer was built with it.
# And libdivecomputer is only built with it if libusb-1.0 is
# installed. So get libusb if it exists, but don't complain
# about it if it doesn't.
LIBUSB = $(shell $(PKGCONFIG) --libs libusb-1.0 2> /dev/null)

# Use qmake to find out which Qt version we are building for.
QT_VERSION_MAJOR = $(shell $(QMAKE) -query QT_VERSION | cut -d. -f1)
ifeq ($(QT_VERSION_MAJOR), 5)
	QT_MODULES = Qt5Widgets Qt5Svg
	QT_CORE = Qt5Core
else
	QT_MODULES = QtGui QtSvg
	QT_CORE = QtCore
endif

# we need GLIB2CFLAGS for gettext
QTCXXFLAGS = $(shell $(PKGCONFIG) --cflags $(QT_MODULES)) $(GLIB2CFLAGS)
LIBQT = $(shell $(PKGCONFIG) --libs $(QT_MODULES))
ifneq ($(filter reduce_relocations, $(shell $(PKGCONFIG) --variable qt_config $(QT_CORE))), )
	QTCXXFLAGS += -fPIE
endif

LIBGTK = $(shell $(PKGCONFIG) --libs gtk+-2.0 glib-2.0)
ifneq (,$(filter $(UNAME),linux kfreebsd gnu))
	LIBGCONF2 = $(shell $(PKGCONFIG) --libs gconf-2.0)
	GCONF2CFLAGS =  $(shell $(PKGCONFIG) --cflags gconf-2.0)
else ifeq ($(UNAME), darwin)
	LIBGTK += $(shell $(PKGCONFIG) --libs gtk-mac-integration) -framework CoreFoundation -framework CoreServices
	GTKCFLAGS += $(shell $(PKGCONFIG) --cflags gtk-mac-integration)
	GTK_MAC_BUNDLER = ~/.local/bin/gtk-mac-bundler
endif

LIBDIVECOMPUTERCFLAGS = $(LIBDIVECOMPUTERINCLUDES)
LIBDIVECOMPUTER = $(LIBDIVECOMPUTERARCHIVE) $(LIBUSB)

LIBXML2 = $(shell $(XML2CONFIG) --libs)
LIBXSLT = $(shell $(XSLCONFIG) --libs)
XML2CFLAGS = $(shell $(XML2CONFIG) --cflags)
GLIB2CFLAGS = $(shell $(PKGCONFIG) --cflags glib-2.0)
GTKCFLAGS = $(shell $(PKGCONFIG) --cflags gtk+-2.0)
XSLCFLAGS = $(shell $(XSLCONFIG) --cflags)
OSMGPSMAPFLAGS += $(shell $(PKGCONFIG) --cflags osmgpsmap 2> /dev/null)
LIBOSMGPSMAP += $(shell $(PKGCONFIG) --libs osmgpsmap 2> /dev/null)
LIBSOUPCFLAGS = $(shell $(PKGCONFIG) --cflags libsoup-2.4)
LIBSOUP = $(shell $(PKGCONFIG) --libs libsoup-2.4)

LIBZIP = $(shell $(PKGCONFIG) --libs libzip 2> /dev/null)
ZIPFLAGS = $(strip $(shell $(PKGCONFIG) --cflags libzip 2> /dev/null))

LIBSQLITE3 = $(shell $(PKGCONFIG) --libs sqlite3 2> /dev/null)
SQLITE3FLAGS = $(strip $(shell $(PKGCONFIG) --cflags sqlite3))

ifneq (,$(filter $(UNAME),linux kfreebsd gnu))
	OSSUPPORT = linux
	OSSUPPORT_CFLAGS = $(GTKCFLAGS) $(GCONF2CFLAGS)
else ifeq ($(UNAME), darwin)
	OSSUPPORT = macos
	OSSUPPORT_CFLAGS = $(GTKCFLAGS)
	MACOSXINSTALL = /Applications/Subsurface.app
	MACOSXFILES = packaging/macosx
	MACOSXSTAGING = $(MACOSXFILES)/Subsurface.app
	INFOPLIST = $(MACOSXFILES)/Info.plist
	INFOPLISTINPUT = $(INFOPLIST).in
	LDFLAGS += -headerpad_max_install_names -sectcreate __TEXT __info_plist $(INFOPLIST)
else
	OSSUPPORT = windows
	OSSUPPORT_CFLAGS = $(GTKCFLAGS)
	WINDOWSSTAGING = ./packaging/windows
	WINMSGDIRS=$(addprefix share/locale/,$(shell ls po/*.po | sed -e 's/po\/\(..\)_.*/\1\/LC_MESSAGES/'))
	NSIINPUTFILE = $(WINDOWSSTAGING)/subsurface.nsi.in
	NSIFILE = $(WINDOWSSTAGING)/subsurface.nsi
	MAKENSIS = makensis
	XSLTDIR = .\\xslt
endif


LIBS = $(LIBQT) $(LIBXML2) $(LIBXSLT) $(LIBSQLITE3) $(LIBGTK) $(LIBGCONF2) $(LIBDIVECOMPUTER) \
	$(EXTRALIBS) $(LIBZIP) -lpthread -lm $(LIBOSMGPSMAP) $(LIBSOUP) $(LIBWINSOCK)

MSGLANGS=$(notdir $(wildcard po/*.po))
MSGOBJS=$(addprefix share/locale/,$(MSGLANGS:.po=.UTF-8/LC_MESSAGES/subsurface.mo))


QTOBJS = qt-ui/maintab.o  qt-ui/mainwindow.o  qt-ui/plotareascene.o qt-ui/divelistview.o \
	 qt-ui/addcylinderdialog.o qt-ui/models.o qt-ui/starwidget.o

GTKOBJS = info-gtk.o divelist-gtk.o planner-gtk.o statistics-gtk.o

OBJS =	main.o dive.o time.o profile.o info.o equipment.o divelist.o deco.o planner.o \
	parse-xml.o save-xml.o libdivecomputer.o print.o uemis.o uemis-downloader.o \
	qt-gui.o statistics.o file.o cochran.o device.o download-dialog.o prefs.o \
	webservice.o sha1.o $(OSSUPPORT).o $(RESFILE) $(QTOBJS) $(GTKOBJS)

# Add files to the following variables if the auto-detection based on the
# filename fails
OBJS_NEEDING_MOC =
OBJS_NEEDING_UIC =
HEADERS_NEEDING_MOC =

# Add the objects for the header files which define QObject subclasses
HEADERS_NEEDING_MOC += $(shell grep -l -s 'Q_OBJECT' $(OBJS:.o=.h))
MOC_OBJS = $(HEADERS_NEEDING_MOC:.h=.moc.o)

ALL_OBJS = $(OBJS) $(MOC_OBJS)

DEPS = $(wildcard .dep/*.dep)

all: $(NAME)

$(NAME): gen_version_file $(ALL_OBJS) $(MSGOBJS) $(INFOPLIST)
	$(CXX) $(LDFLAGS) -o $(NAME) $(ALL_OBJS) $(LIBS)

gen_version_file:
ifneq ($(STORED_VERSION_STRING),$(VERSION_STRING))
	$(info updating $(VERSION_FILE) to $(VERSION_STRING))
	@echo \#define VERSION_STRING \"$(VERSION_STRING)\" >$(VERSION_FILE)
endif

install: all
	$(INSTALL) -d -m 755 $(BINDIR)
	$(INSTALL) $(NAME) $(BINDIR)
	$(INSTALL) -d -m 755 $(DESKTOPDIR)
	$(INSTALL) $(DESKTOPFILE) $(DESKTOPDIR)
	$(INSTALL) -d -m 755 $(ICONDIR)
	$(INSTALL) -m 644 $(ICONFILE) $(ICONDIR)
	@-if test -z "$(DESTDIR)"; then \
		$(gtk_update_icon_cache); \
	fi
	$(INSTALL) -d -m 755 $(MANDIR)
	$(INSTALL) -m 644 $(MANFILES) $(MANDIR)
	@-if test ! -z "$(XSLT)"; then \
		$(INSTALL) -d -m 755 $(DATADIR)/subsurface; \
		$(INSTALL) -d -m 755 $(XSLTDIR); \
		$(INSTALL) -m 644 $(XSLTFILES) $(XSLTDIR); \
	fi
	for LOC in $(wildcard share/locale/*/LC_MESSAGES); do \
		$(INSTALL) -d $(prefix)/$$LOC; \
		$(INSTALL) -m 644 $$LOC/subsurface.mo $(prefix)/$$LOC/subsurface.mo; \
	done


install-macosx: all
	$(INSTALL) -d -m 755 $(MACOSXINSTALL)/Contents/Resources
	$(INSTALL) -d -m 755 $(MACOSXINSTALL)/Contents/MacOS
	$(INSTALL) $(NAME) $(MACOSXINSTALL)/Contents/MacOS/$(NAME)-bin
	$(INSTALL) $(MACOSXFILES)/$(NAME).sh $(MACOSXINSTALL)/Contents/MacOS/$(NAME)
	$(INSTALL) $(MACOSXFILES)/PkgInfo $(MACOSXINSTALL)/Contents/
	$(INSTALL) $(MACOSXFILES)/Info.plist $(MACOSXINSTALL)/Contents/
	$(INSTALL) $(ICONFILE) $(MACOSXINSTALL)/Contents/Resources/
	$(INSTALL) $(MACOSXFILES)/Subsurface.icns $(MACOSXINSTALL)/Contents/Resources/
	for LOC in $(wildcard share/locale/*/LC_MESSAGES); do \
		$(INSTALL) -d -m 755 $(MACOSXINSTALL)/Contents/Resources/$$LOC; \
		$(INSTALL) $$LOC/subsurface.mo $(MACOSXINSTALL)/Contents/Resources/$$LOC/subsurface.mo; \
	done
	@-if test ! -z "$(XSLT)"; then \
		$(INSTALL) -d -m 755 $(MACOSXINSTALL)/Contents/Resources/xslt; \
		$(INSTALL) -m 644 $(XSLTFILES) $(MACOSXINSTALL)/Contents/Resources/xslt/; \
	fi


create-macosx-bundle: all
	$(INSTALL) -d -m 755 $(MACOSXSTAGING)/Contents/Resources
	$(INSTALL) -d -m 755 $(MACOSXSTAGING)/Contents/MacOS
	$(INSTALL) $(NAME) $(MACOSXSTAGING)/Contents/MacOS/
	$(INSTALL) $(MACOSXFILES)/PkgInfo $(MACOSXSTAGING)/Contents/
	$(INSTALL) $(MACOSXFILES)/Info.plist $(MACOSXSTAGING)/Contents/
	$(INSTALL) $(ICONFILE) $(MACOSXSTAGING)/Contents/Resources/
	$(INSTALL) $(MACOSXFILES)/Subsurface.icns $(MACOSXSTAGING)/Contents/Resources/
	for LOC in $(wildcard share/locale/*/LC_MESSAGES); do \
		$(INSTALL) -d -m 755 $(MACOSXSTAGING)/Contents/Resources/$$LOC; \
		$(INSTALL) $$LOC/subsurface.mo $(MACOSXSTAGING)/Contents/Resources/$$LOC/subsurface.mo; \
	done
	@-if test ! -z "$(XSLT)"; then \
		$(INSTALL) -d -m 755 $(MACOSXSTAGING)/Contents/Resources/xslt; \
		$(INSTALL) -m 644 $(XSLTFILES) $(MACOSXSTAGING)/Contents/Resources/xslt/; \
	fi
	$(GTK_MAC_BUNDLER) packaging/macosx/subsurface.bundle

sign-macosx-bundle: all
	codesign -s "3A8CE62A483083EDEA5581A61E770EC1FA8BECE8" /Applications/Subsurface.app/Contents/MacOS/subsurface-bin

install-cross-windows: all
	$(INSTALL) -d -m 755 $(WINDOWSSTAGING)/share/locale
	for MSG in $(WINMSGDIRS); do\
		$(INSTALL) -d -m 755 $(WINDOWSSTAGING)/$$MSG;\
		$(INSTALL) $(CROSS_PATH)/$$MSG/* $(WINDOWSSTAGING)/$$MSG;\
	done
	for LOC in $(wildcard share/locale/*/LC_MESSAGES); do \
		$(INSTALL) -d -m 755 $(WINDOWSSTAGING)/$$LOC; \
		$(INSTALL) $$LOC/subsurface.mo $(WINDOWSSTAGING)/$$LOC/subsurface.mo; \
	done

create-windows-installer: all $(NSIFILE) install-cross-windows
	$(MAKENSIS) $(NSIFILE)

$(NSIFILE): $(NSIINPUTFILE)
	$(shell cat $(NSIINPUTFILE) | sed -e 's/VERSIONTOKEN/$(VERSION_STRING)/;s/PRODVTOKEN/$(PRODVERSION_STRING)/' > $(NSIFILE))

$(INFOPLIST): $(INFOPLISTINPUT)
	$(shell cat $(INFOPLISTINPUT) | sed -e 's/CFBUNDLEVERSION_TOKEN/$(CFBUNDLEVERSION_STRING)/' > $(INFOPLIST))

# Transifex merge the translations
update-po-files:
	xgettext -o po/subsurface-new.pot -s -k_ -kN_ -ktr --keyword=C_:1c,2  --add-comments="++GETTEXT" *.c qt-ui/*.cpp
	tx push -s
	tx pull -af

EXTRA_FLAGS =	$(QTCXXFLAGS) $(GTKCFLAGS) $(GLIB2CFLAGS) $(XML2CFLAGS) \
		$(LIBDIVECOMPUTERCFLAGS) \
		$(LIBSOUPCFLAGS) $(GCONF2CFLAGS)

ifneq ($(SQLITE3FLAGS),)
	EXTRA_FLAGS += -DSQLITE3 $(SQLITE3FLAGS)
endif
ifneq ($(ZIPFLAGS),)
	EXTRA_FLAGS += -DLIBZIP $(ZIPFLAGS)
endif
ifneq ($(strip $(LIBXSLT)),)
	EXTRA_FLAGS += -DXSLT='"$(XSLTDIR)"' $(XSLCFLAGS)
endif
ifneq ($(strip $(LIBOSMGPSMAP)),)
	OBJS += gps.o
	EXTRA_FLAGS += -DHAVE_OSM_GPS_MAP $(OSMGPSMAPFLAGS)
endif

MOCFLAGS = $(filter -I%, $(CXXFLAGS) $(EXTRA_FLAGS)) $(filter -D%, $(CXXFLAGS) $(EXTRA_FLAGS))

%.o: %.c
	@echo '    CC' $<
	@mkdir -p .dep .dep/qt-ui
	@$(CC) $(CFLAGS) $(EXTRA_FLAGS) -MD -MF .dep/$@.dep -c -o $@ $<

%.o: %.cpp
	@echo '    CXX' $<
	@mkdir -p .dep .dep/qt-ui
	@$(CXX) $(CXXFLAGS) $(EXTRA_FLAGS) -MD -MF .dep/$@.dep -c -o $@ $<

# Detect which files require the moc or uic tools to be run
CPP_NEEDING_MOC = $(shell grep -l -s '^\#include \".*\.moc\"' $(OBJS:.o=.cpp))
OBJS_NEEDING_MOC += $(CPP_NEEDING_MOC:.cpp=.o)

CPP_NEEDING_UIC = $(shell grep -l -s '^\#include \"ui_.*\.h\"' $(OBJS:.o=.cpp))
OBJS_NEEDING_UIC += $(CPP_NEEDING_UIC:.cpp=.o)

# This rule is for running the moc on QObject subclasses defined in the .h
# files.
%.moc.cpp: %.h
	@echo '    MOC' $<
	@$(MOC) $(MOCFLAGS) $< -o $@

# This rule is for running the moc on QObject subclasses defined in the .cpp
# files; remember to #include "<file>.moc" at the end of the .cpp file, or
# you'll get linker errors ("undefined vtable for...")
%.moc: %.cpp
	@echo '    MOC' $<
	@$(MOC) -i $(MOCFLAGS) $< -o $@

# This creates the ui headers.
ui_%.h: %.ui
	@echo '    UIC' $<
	@$(UIC) $< -o $@

$(OBJS_NEEDING_MOC): %.o: %.moc
$(OBJS_NEEDING_UIC): qt-ui/%.o: qt-ui/ui_%.h

share/locale/%.UTF-8/LC_MESSAGES/subsurface.mo: po/%.po po/%.aliases
	mkdir -p $(dir $@)
	msgfmt -c -o $@ po/$*.po
	@-if test -s po/$*.aliases; then \
		for ALIAS in `cat po/$*.aliases`; do \
			mkdir -p share/locale/$$ALIAS/LC_MESSAGES; \
			cp $@ share/locale/$$ALIAS/LC_MESSAGES; \
		done; \
	fi

satellite.png: satellite.svg
	convert -transparent white -resize 11x16 -depth 8 $< $@

# This should work, but it doesn't get the colors quite right - so I manually converted with Gimp
#	convert -colorspace RGB -transparent white -resize 256x256 subsurface-icon.svg subsurface-icon.png
#
# The following creates the pixbuf data in .h files with the basename followed by '_pixmap'
# as name of the data structure
%.h: %.png
	@echo '    gdk-pixbuf-csource' $<
	@gdk-pixbuf-csource --struct --name `echo $* | sed 's/-/_/g'`_pixbuf $< > $@

doc:
	$(MAKE) -C Documentation doc

clean:
	rm -f $(ALL_OBJS) *~ $(NAME) $(NAME).exe po/*~ po/subsurface-new.pot \
		$(VERSION_FILE) qt-ui/*.moc qt-ui/ui_*.h
	rm -rf share .dep

-include $(DEPS)
