#!/bin/bash
set -e

# Update package lists
apt-get update -qq

exec /usr/sbin/sshd -D
