#!/bin/bash
# Make it work on any interactive terminal (not just SSH)
sudo sed -i 's/if \[\[ $- == \*i\* \]\] && \[\[ -n "$SSH_CONNECTION" || -n "$SSH_CLIENT" || -n "$SSH_TTY" \]\]; then/if [[ $- == *i* ]]; then/' /etc/profile.d/00-dynamic-motd.sh