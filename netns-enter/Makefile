CFLAGS = -g -O2 -std=gnu2x -fhardened -Wall -Wextra -Werror -Wno-missing-field-initializers
LDFLAGS=

netns-enter: netns-enter.o
	$(CC) $^ $(CFLAGS) $(LDFLAGS) -o $@

%.o: %.c
	$(CC) -c $(CFLAGS) $< -o $@

.PHONY: install clean

install: netns-enter
	install -o root -g root -m 4755 $< /usr/local/bin

clean:
	rm -f netns-enter *.o
