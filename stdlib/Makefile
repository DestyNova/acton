TD:=$(shell dirname $(realpath ../$(firstword $(MAKEFILE_LIST))))
CC=$(TD)/dist/zig/zig cc
CFLAGS+= -L$(TD)/dist/lib -I$(TD)/dist/inc -fno-common -I.. -I../dist -I../dist/inc -L../lib -Wno-int-to-pointer-cast -Wno-pointer-to-int-cast -Wformat -Werror=format-security
CFLAGS_REL= -O3 -DREL
CFLAGS_DEV= -g -DDEV

out/dev/lib/math.o: src/math.c
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) $(CFLAGS_DEV) -Iout/ -c $< -o$@

out/rel/lib/math.o: src/math.c
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) $(CFLAGS_REL) -Iout/ -c $< -o$@


NUMPY_CFILES=$(wildcard c_src/numpy/*.h)
out/dev/lib/numpy.o: src/numpy.c src/numpy.h out/types/math.h $(NUMPY_CFILES)
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) $(CFLAGS_DEV) -Wno-unused-result -Iout/ -c $< -o$@

out/rel/lib/numpy.o: src/numpy.c src/numpy.h out/types/math.h $(NUMPY_CFILES)
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) $(CFLAGS_REL) -Wno-unused-result -Iout/ -c $< -o$@
