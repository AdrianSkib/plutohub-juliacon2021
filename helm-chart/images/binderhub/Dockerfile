# We use a build stage to package binderhub and pycurl into a wheel which we
# then install by itself in the final image which is relatively slimmed.
# ARG DIST=buster


# # The build stage
# # ---------------
# FROM python:3.8-$DIST as build-stage
# # ARG DIST is defined again to be made available in this build stage's scope.
# # ref: https://docs.docker.com/engine/reference/builder/#understand-how-arg-and-from-interact
# ARG DIST

# # Install node as required to package binderhub to a wheel
# RUN echo "deb http://deb.nodesource.com/node_14.x $DIST main" > /etc/apt/sources.list.d/nodesource.list \
#  && curl -s https://deb.nodesource.com/gpgkey/nodesource.gpg.key | apt-key add -
# RUN apt-get update \
#  && apt-get install --yes \
#         nodejs \
#  && rm -rf /var/lib/apt/lists/*

# # Copy the whole git repository to /tmp/binderhub
# COPY . /tmp/binderhub
# WORKDIR /tmp/binderhub

# # Build the binderhub python library into a wheel and save it to the ./dist
# # folder. There are no pycurl or ruamel.yaml.clib wheels so we build our own in
# # the build stage.
# RUN python -mpip install build && python -mbuild --wheel .
# RUN pip wheel --wheel-dir ./dist \
#        pycurl \
#        ruamel.yaml.clib

# # We download tini from here were we have wget available.
# RUN ARCH=$(uname -m); \
#     if [ "$ARCH" = x86_64 ]; then ARCH=amd64; fi; \
#     if [ "$ARCH" = aarch64 ]; then ARCH=arm64; fi; \
#     wget -qO /tini "https://github.com/krallin/tini/releases/download/v0.19.0/tini-$ARCH" \
#  && chmod +x /tini

# # The final stage
# # ---------------
# FROM python:3.8-slim-$DIST
# WORKDIR /

# # Add non-root user since this is required by radix container
# # Add a new group "radix-non-root-group" with group id 1001 
# RUN groupadd -g 1000 radix-non-root-group

# # Add a new user "radix-non-root-user" with user id 1001 and include in group
# RUN useradd -u 1000 -u 1000 radix-non-root-user

# RUN mkdir -p /home/radix-non-root-user
# # Give non-root user access to folder where everything will be run from
# RUN chown -R radix-non-root-user:radix-non-root-group /home/radix-non-root-user


# # We use tini as an entrypoint to not loose track of SIGTERM signals as sent
# # before SIGKILL when "docker stop" or "kubectl delete pod" is run. By doing
# # that the pod can terminate very quickly.
# COPY --from=build-stage --chown=radix-non-root-user:radix-non-root-group /tini /tini
 
# # The slim version doesn't include git as required by binderhub
# RUN apt-get update \
#  && apt-get install --yes \
#         git \
#  && rm -rf /var/lib/apt/lists/*

# # Change to user 1000
# USER 1000

# # Copy the built wheels from the build-stage. Also copy the image
# # requirements.txt built from the binderhub package requirements.txt and the
# # requirements.in file using the ./dependency script.
# COPY --from=build-stage --chown=radix-non-root-user:radix-non-root-group /tmp/binderhub/dist/*.whl pre-built-wheels/
# COPY --chown=radix-non-root-user:radix-non-root-group helm-chart/images/binderhub/requirements.txt .
# # COPY --chown=radix-non-root-user:radix-non-root-group config .kube

# # Install pre-built wheels and the generated requirements.txt for the image.
# RUN pip install --no-cache-dir \
#         pre-built-wheels/*.whl \
#         -r requirements.txt

# # When using the ./dependency script to output a frozen environment, we do it
# # from within this container. So below we conditionally install pip-tools for
# # use by the ./dependency script.
# ARG PIP_TOOLS=
# RUN test -z "$PIP_TOOLS" || pip install --no-cache pip-tools==$PIP_TOOLS

# ENV KUBECONFIG=/etc/kubernetes/admin.conf

# ENV PATH="/home/radix-non-root-user/.local/bin:${PATH}"
# ENTRYPOINT ["/tini", "--", "python3", "-m", "binderhub"]
# CMD ["--config", "/etc/binderhub/config/binderhub_config.py"]
# ENV PYTHONUNBUFFERED=1
# EXPOSE 8585

FROM jupyterhub/jupyterhub

EXPOSE 8585

ENTRYPOINT [ "jupyterhub --ip 0.0.0.0 --port 8585" ]