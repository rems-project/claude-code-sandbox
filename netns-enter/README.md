## netns-enter ##

Executable for entering network namespaces without privileges. Wraps `ip` and
`setpriv` invocations; must be installed suid-root.

The file `/usr/local/etc/netns-enter` (`$CFG`) lists allowed namespaces.
