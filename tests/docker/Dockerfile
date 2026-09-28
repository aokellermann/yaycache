# Disposable Arch Linux environment for the yaycache test suite.
# Built and run by tests/docker/run.sh; nothing here touches the host.
FROM archlinux:base-devel

RUN pacman -Syu --noconfirm --needed git pacman-contrib bubblewrap asciidoc \
	&& pacman -Scc --noconfirm

# Tests must run unprivileged: writability checks and the sudo path are
# meaningless for root.
RUN useradd -m -s /bin/bash tester

COPY --chown=tester:tester . /src
USER tester
WORKDIR /src

# The container itself is the isolation boundary; bubblewrap needs user
# namespaces that docker's default seccomp profile does not grant.
ENV YAYCACHE_NO_SANDBOX=1

RUN ./autogen.sh && ./configure --prefix=/usr && make

CMD ["tests/docker/entrypoint.sh"]
