FROM ubuntu:26.04

ENV DEBIAN_FRONTEND=noninteractive

# Set up a user 'remi' with passwordless sudo (matches hardcoded paths)
RUN apt-get update && \
    apt-get install -y sudo && \
    useradd -m -s /bin/bash -d /home/remi remi && \
    echo 'remi ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/remi && \
    chmod 0440 /etc/sudoers.d/remi && \
    rm -rf /var/lib/apt/lists/*

# No systemd as PID 1, no netfilter, no bootloader: stand-ins for what install.sh
# calls. dpkg runs maintainer scripts with PATH=/usr/sbin:/usr/bin:/sbin:/bin, so
# divert the real paths (packages installed later land at *.distrib). systemctl
# keeps its offline verbs (without --now) and reports services inactive; the rest
# are no-ops. The ZBook block runs here too (DMI comes from the host): stock grub.
RUN for f in /usr/sbin/ufw /usr/sbin/update-grub /usr/sbin/update-initramfs /usr/bin/systemctl; do \
      dpkg-divert --local --rename --divert "$f.distrib" --add "$f" && \
      printf '#!/bin/sh\n' > "$f" && chmod 755 "$f"; \
    done && \
    printf '%s\n' '#!/bin/sh' \
      'case "$1" in' \
      '  enable|disable|mask|unmask|is-enabled|preset)' \
      '    for a; do shift; [ "$a" = --now ] || set -- "$@" "$a"; done' \
      '    exec /usr/bin/systemctl.distrib "$@" ;;' \
      '  is-active|is-failed) exit 3 ;;' \
      'esac' > /usr/bin/systemctl && \
    printf 'GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"\n' > /etc/default/grub

COPY --chown=remi:remi . /home/remi/.dot

ENV USER=remi
USER remi
WORKDIR /home/remi/.dot

# Skip snap (no snapd), Docker (no Docker-in-Docker), 1Password, AI tools, firejail
ENV DOTFILES_SKIP_SNAP=1
ENV DOTFILES_SKIP_DOCKER=1
ENV DOTFILES_SKIP_1PASSWORD=1
ENV DOTFILES_SKIP_AI_TOOLS=1
ENV DOTFILES_SKIP_FIREJAIL=1

CMD ["bash", "-c", "./install.sh && ./test/e2e.sh"]
