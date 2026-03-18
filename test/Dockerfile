FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# Set up a user 'remi' with passwordless sudo (matches hardcoded paths)
RUN apt-get update && \
    apt-get install -y sudo && \
    useradd -m -s /bin/bash -d /home/remi remi && \
    echo 'remi ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/remi && \
    chmod 0440 /etc/sudoers.d/remi && \
    rm -rf /var/lib/apt/lists/*

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
