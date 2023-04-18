FROM python:3.9-buster

RUN pip install pip --upgrade
RUN pip install ansible
RUN pip install ansible-lint
RUN pip install flake8
RUN pip install black
RUN pip install pyyaml
RUN pip install testinfra
RUN pip install pytest


RUN apt-get update -y && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    sshpass \
    ansible-lint \
    jq
