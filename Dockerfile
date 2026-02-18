FROM docker.io/cloudflare/sandbox:0.6.7

ENV PATH="/root/.opencode/bin:${PATH}"

RUN curl -fsSL https://opencode.ai/install -o /tmp/install-opencode.sh \
    && bash /tmp/install-opencode.sh \
    && rm /tmp/install-opencode.sh \
    && opencode --version

RUN mkdir -p /mnt/efs/workspace && chmod 755 /mnt/efs/workspace

WORKDIR /mnt/efs/workspace

EXPOSE 4096

CMD ["opencode", "serve", "--port", "4096", "--hostname", "0.0.0.0"]
