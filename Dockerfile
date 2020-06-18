FROM cs50/cli

USER root

ARG DEBIANFRONTEND=noninteractive

RUN apt-get update -qq && apt-get install -y jq

# Install Python packages
# TODO remove werkzeug after https://github.com/fengsp/flask-session/issues/99 is fixed
RUN pip3 install \
        flask_sqlalchemy \
        nltk \
        numpy \
        pandas \
        passlib \
        plotly \
        pytz \
        cffi \
        'werkzeug<1.0.0' \
        'scikit-learn==0.22.1' \
        'tensorflow==2.1.0' \
        opencv-python && \
    python3 -m nltk.downloader -d /usr/share/nltk_data/ punkt

# Copy container initialization
COPY ./docker-entry.sh /
RUN chmod a+x /docker-entry.sh

RUN sed -i '/^ubuntu ALL=(ALL) NOPASSWD:ALL$/d' /etc/sudoers

USER ubuntu

# Clone checks
ENV CHECK50_PATH  "~/.local/share/check50"

# Configure git
RUN git config --global user.name bot50 && \
    git config --global user.email bot@cs50.harvard.edu

ENV CHECK50_WORKERS "4"

# Copy Travis testing (need to do as root)
USER root
COPY validate/ /validate/

# Generate key
RUN [ "openssl", "genpkey", "-out", "/private.pem", "-outform", "PEM", "--algorithm", "RSA", "-pkeyopt", "rsa_keygen_bits:2048" ]
RUN [ "chmod", "+r", "/private.pem" ]
RUN [ "openssl", "pkey", "-pubout", "-inform", "PEM", "-outform", "PEM", "-in", "/private.pem", "-out", "/validate/public.pem" ]

USER ubuntu

# Run build test
RUN [ "/docker-entry.sh", "-o", "me50", "-r", "cs50student2", "-b", "cs50/problems/2020/x/hello", "-c", "e03bee664b4c310579025e494eb086b213c01626", "-s", "-k", "/private.pem", "-u", "http://localhost:8080/validate"]
