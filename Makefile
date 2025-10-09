CLIENT			= client
SERVER			= server
CC				?= gcc

CFLAGS_BASE		= -std=gnu11

CFLAGS_STRICT	= -Wstrict-aliasing=2 -Wall -Wextra -Werror -Wpedantic \
				  -Wwrite-strings -Wconversion -Wmissing-declarations \
				  -Wmissing-include-dirs -Wfloat-equal -Wsign-compare -Wundef \
				  -Wcast-align -Wswitch-default -Wimplicit-fallthrough \
				  -Wempty-body -Wuninitialized -Wmisleading-indentation \
				  -Wshadow -Wmissing-prototypes -Wstrict-prototypes \
				  -Wold-style-definition

CFLAGS_RELEASE	= -O3 -march=native -flto=auto -fno-plt -fomit-frame-pointer

CFLAGS_DEBUG	= -O0 -g3 -ggdb3 -fno-strict-aliasing -fstack-protector-strong \
				  -DDEBUG -fno-omit-frame-pointer -fsanitize=address \
				  -fsanitize-address-use-after-scope -ftrapv

LDLIBS_BASE		=

LDLIBS_RELEASE	= -flto

LDLIBS_DEBUG	= -fsanitize=address -fsanitize-address-use-after-scope

CFLAGS		?= $(CFLAGS_BASE)
LDLIBS		?= $(LDLIBS_BASE)

%: src/%.c
	$(CC) $(CFLAGS) $^ -o $@ $(LDLIBS)

.PHONY: all clean rebuild release debug

all: $(CLIENT) $(SERVER)

release: CFLAGS = $(CFLAGS_BASE) $(CFLAGS_STRICT) $(CFLAGS_RELEASE)
release: LDLIBS = $(LDLIBS_BASE) $(LDLIBS_RELEASE)
release: all

debug: CFLAGS = $(CFLAGS_BASE) $(CFLAGS_STRICT) $(CFLAGS_DEBUG)
debug: LDLIBS = $(LDLIBS_BASE) $(LDLIBS_DEBUG)
debug: all

clean:
	$(RM) -f $(CLIENT)
	$(RM) -f $(SERVER)

rebuild: clean all
