SRCS=$(wildcard src/*.c)
OBJS=$(SRCS:.c=.o)
CLIBS=$(SRCS:.c=.$(LIB_EXTENSION))
LLIBS=$(wildcard lib/*.lua)
INSTALL?=install

ifdef FORK_COVERAGE
COVFLAGS=--coverage
endif

.PHONY: all install

all: $(CLIBS)

%.o: %.c
	$(CC) $(CFLAGS) $(WARNINGS) $(COVFLAGS) $(CPPFLAGS) -o $@ -c $<

%.$(LIB_EXTENSION): %.o
	$(CC) -o $@ $^ $(LDFLAGS) $(LIBS) $(PLATFORM_LDFLAGS) $(COVFLAGS)

install:
	$(INSTALL) fork.lua $(INST_LUADIR)
	$(INSTALL) -d $(INST_LLIBDIR)
	$(INSTALL) $(LLIBS) $(INST_LLIBDIR)
	$(INSTALL) -d $(INST_CLIBDIR)
	$(INSTALL) $(CLIBS) $(INST_CLIBDIR)
	rm -f $(OBJS) $(CLIBS) ./src/*.gcda
