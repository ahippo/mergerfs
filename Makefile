#  Copyright (c) 2016, Antonio SJ Musumeci <trapexit@spawn.link>
#
#  Permission to use, copy, modify, and/or distribute this software for any
#  purpose with or without fee is hereby granted, provided that the above
#  copyright notice and this permission notice appear in all copies.
#
#  THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
#  WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
#  MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
#  ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
#  WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
#  ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
#  OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

GIT       = git
TAR       = tar
MKDIR     = mkdir
TOUCH     = touch
CP        = cp
RM        = rm
LN        = ln
FIND      = find
INSTALL   = install
MKTEMP    = mktemp
STRIP     = strip
PANDOC    = pandoc
SED       = sed
GZIP      = gzip
RPMBUILD  = rpmbuild
GIT2DEBCL = ./tools/git2debcl
PKGCONFIG = pkg-config

GIT_REPO = 0
ifneq ($(GIT),)
ifneq ($(shell $(GIT) --version 2>/dev/null),)
ifeq  ($(shell test -e .git; echo $$?),0)
GIT_REPO = 1
endif
endif
endif

ifneq ($(PANDOC),)
ifeq ($(shell $(PANDOC) --version 2>/dev/null),)
PANDOC :=
endif
endif
ifeq ($(PANDOC),)
$(warning "pandoc does not appear available: manpage won't be buildable")
endif

XATTR_AVAILABLE = $(shell test ! -e /usr/include/attr/xattr.h; echo $$?)

INTERNAL_FUSE = 1
EXTERNAL_FUSE_MIN_REQ = 2.9.7

ifeq ($(INTERNAL_FUSE),1)
FUSE_CFLAGS = -D_FILE_OFFSET_BITS=64 -Ilibfuse/include
FUSE_LIBS   = libfuse/lib/.libs/libfuse.a
FUSE_TARGET = $(FUSE_LIBS)
else
FUSE_CFLAGS := $(shell $(PKGCONFIG) --cflags 'fuse >= $(EXTERNAL_FUSE_MIN_REQ)')
FUSE_LIBS   := $(shell $(PKGCONFIG) --libs   'fuse >= $(EXTERNAL_FUSE_MIN_REQ)')
FUSE_TARGET :=
ifeq ($(FUSE_CFLAGS)$(FUSE_LIBS),)
$(error "Use of external FUSE requested, but no libfuse >= $(EXTERNAL_FUSE_MIN_REQ) found.")
endif
endif

UGID_USE_RWLOCK = 0

OPTS 	    = -g -O2
SRC	    = $(wildcard src/*.cpp)
OBJ         = $(SRC:src/%.cpp=obj/%.o)
DEPS        = $(OBJ:obj/%.o=obj/%.d)
TARGET      = mergerfs
MANPAGE     = $(TARGET).1
CFLAGS      = -Wall \
	      $(OPTS) \
	      -Wno-unused-result \
              $(FUSE_CFLAGS) \
              -DFUSE_USE_VERSION=29 \
              -MMD \
	      -DUGID_USE_RWLOCK=$(UGID_USE_RWLOCK)

PREFIX        = /usr/local
EXEC_PREFIX   = $(PREFIX)
DATAROOTDIR   = $(PREFIX)/share
DATADIR       = $(DATAROOTDIR)
BINDIR        = $(EXEC_PREFIX)/bin
SBINDIR       = $(EXEC_PREFIX)/sbin
MANDIR        = $(DATAROOTDIR)/man
MAN1DIR       = $(MANDIR)/man1

INSTALLBINDIR  = $(DESTDIR)$(BINDIR)
INSTALLSBINDIR = $(DESTDIR)$(SBINDIR)
INSTALLMAN1DIR = $(DESTDIR)$(MAN1DIR)

ifeq ($(XATTR_AVAILABLE),0)
$(warning "xattr not available: disabling")
CFLAGS += -DWITHOUT_XATTR
endif

all: $(TARGET)

help:
	@echo "usage: make"
	@echo "make XATTR_AVAILABLE=0 - to build program without xattrs functionality (auto discovered otherwise)"
	@echo "make INTERNAL_FUSE=0   - to build program with external (system) libfuse rather than the bundled one ('-o threads=' option will be unavailable)"

$(TARGET): version obj/obj-stamp $(FUSE_TARGET) $(OBJ)
	$(CXX) $(CPPFLAGS) $(CFLAGS) $(LDFLAGS) $(OBJ) -o $@ $(FUSE_LIBS) -ldl -pthread -lrt

mount.mergerfs: $(TARGET)
	$(LN) -fs "$<" "$@"

changelog:
ifeq ($(GIT_REPO),1)
	$(GIT2DEBCL) --name $(TARGET) > ChangeLog
endif

authors:
ifeq ($(GIT_REPO),1)
	$(GIT) log --format='%aN <%aE>' | sort -f | uniq > AUTHORS
endif

version:
	tools/update-version

obj/obj-stamp:
	$(MKDIR) -p obj
	$(TOUCH) $@

obj/%.o: src/%.cpp
	$(CXX) $(CPPFLAGS) $(CFLAGS) -c $< -o $@

clean: rpm-clean libfuse_Makefile
	$(RM) -f src/version.hpp
	$(RM) -rf obj
	$(RM) -f "$(TARGET)" mount.mergerfs
	$(FIND) . -name "*~" -delete
ifeq ($(INTERNAL_FUSE),1)
	cd libfuse && $(MAKE) clean
endif

distclean: clean libfuse_Makefile
ifeq ($(INTERNAL_FUSE),1)
	cd libfuse && $(MAKE) distclean
endif
ifeq ($(GIT_REPO),1)
	$(GIT) clean -fd
endif

install: install-base install-mount.mergerfs install-man

install-base: $(TARGET)
	$(MKDIR) -p "$(INSTALLBINDIR)"
	$(INSTALL) -v -m 0755 "$(TARGET)" "$(INSTALLBINDIR)/$(TARGET)"

install-mount.mergerfs: mount.mergerfs
	$(MKDIR) -p "$(INSTALLBINDIR)"
	$(CP) -a "$<" "$(INSTALLBINDIR)/$<"

install-man: $(MANPAGE)
	$(MKDIR) -p "$(INSTALLMAN1DIR)"
	$(INSTALL) -v -m 0644 "man/$(MANPAGE)" "$(INSTALLMAN1DIR)/$(MANPAGE)"

install-strip: install-base
	$(STRIP) "$(INSTALLBINDIR)/$(TARGET)"

uninstall: uninstall-base uninstall-mount.mergerfs uninstall-man

uninstall-base:
	$(RM) -f "$(INSTALLBINDIR)/$(TARGET)"

uninstall-mount.mergerfs:
	$(RM) -f "$(INSTALLBINDIR)/mount.mergerfs"

uninstall-man:
	$(RM) -f "$(INSTALLMAN1DIR)/$(MANPAGE)"

$(MANPAGE): README.md
ifneq ($(PANDOC),)
	$(PANDOC) -s -t man -o "man/$(MANPAGE)" README.md
endif

man: $(MANPAGE)

tarball: distclean man changelog authors version
	$(eval VERSION := $(shell cat VERSION))
	$(eval VERSION := $(subst -,_,$(VERSION)))
	$(eval FILENAME := $(TARGET)-$(VERSION))
	$(eval TMPDIR := $(shell $(MKTEMP) --tmpdir -d .$(FILENAME).XXXXXXXX))
	$(MKDIR) $(TMPDIR)/$(FILENAME)
	$(CP) -ar . $(TMPDIR)/$(FILENAME)
	$(TAR) --exclude=.git -cz -C $(TMPDIR) -f $(FILENAME).tar.gz $(FILENAME)
	$(RM) -rf $(TMPDIR)

debian-changelog:
ifeq ($(GIT_REPO),1)
	$(GIT2DEBCL) --name $(TARGET) > debian/changelog
else
	cp ChangeLog debian/changelog
endif

signed-deb: debian-changelog
	dpkg-buildpackage

deb: debian-changelog
	dpkg-buildpackage -uc -us

rpm-clean:
	$(RM) -rf rpmbuild

rpm: tarball
	$(eval VERSION := $(shell cat VERSION))
	$(eval VERSION := $(subst -,_,$(VERSION)))
	$(MKDIR) -p rpmbuild/BUILD rpmbuild/RPMS rpmbuild/SOURCES
	$(SED) 's/__VERSION__/$(VERSION)/g' $(TARGET).spec > \
		rpmbuild/SOURCES/$(TARGET).spec
	cp -ar $(TARGET)-$(VERSION).tar.gz rpmbuild/SOURCES
	$(RPMBUILD) -ba rpmbuild/SOURCES/$(TARGET).spec \
		--define "_topdir $(CURDIR)/rpmbuild"

install-build-pkgs:
ifeq ($(shell test -e /usr/bin/apt-get; echo $$?),0)
	apt-get -qy update
	apt-get -qy --no-install-suggests --no-install-recommends --force-yes \
		install build-essential git g++ debhelper libattr1-dev python automake libtool lsb-release
else ifeq ($(shell test -e /usr/bin/dnf; echo $$?),0)
	dnf -y update
	dnf -y install git rpm-build libattr-devel gcc-c++ make which python automake libtool gettext-devel
else ifeq ($(shell test -e /usr/bin/yum; echo $$?),0)
	yum -y update
	yum -y install git rpm-build libattr-devel gcc-c++ make which python automake libtool gettext-devel
endif

unexport CFLAGS
.PHONY: libfuse_Makefile
libfuse_Makefile:
ifeq ($(INTERNAL_FUSE),1)
ifeq ($(shell test -e libfuse/Makefile; echo $$?),1)
	cd libfuse && \
	$(MKDIR) -p m4 && \
	autoreconf --force --install && \
        ./configure --enable-lib --disable-util --disable-example
endif
endif

libfuse/lib/.libs/libfuse.a: libfuse_Makefile
	cd libfuse && $(MAKE)

.PHONY: all clean install help version

-include $(DEPS)
