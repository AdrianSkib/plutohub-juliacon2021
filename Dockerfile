# # Build as jupyterhub/singleuser
# # Run with the DockerSpawner in JupyterHub

# FROM jupyter/scipy-notebook

# # no need for singleuser Dockerfile anymore,
# # all scripts have been ported to jupyter/base-notebook docker image

# USER root

# RUN apt-get update \
#     && apt-get upgrade -y -o Dpkg::Options::="--force-confdef" -o DPkg::Options::="--force-confold" \
#     && apt-get install -y \
#     curl \
#     libzmq3-dev \
#     hdf5-tools \
#     gettext \
#     pdf2svg \
#     libpangocairo-1.0 \
#     octave \
#     texlive-luatex \
#     g++

# RUN conda install -y conda-build jupyterlab rise nodejs && conda build purge-all && fix-permissions $CONDA_DIR

# RUN jupyter serverextension enable jupyterlab --py --sys-prefix

# USER root

# # Extra latex packages
# RUN apt-get update \
#     && apt-get install -y \
#     texlive-science

# USER $NB_USER

# RUN mkdir /home/$NB_USER/work/coursefiles

# ENV NOTEBOOK_DIR="/home/${NB_USER}/work"

# ############# Julia 1.6 #####################
# USER root
# RUN rm -rf /opt/julia-1.6

# RUN mkdir -p /opt/julia-1.6 && \
#     curl -s -L https://julialang-s3.julialang.org/bin/linux/x64/1.6/julia-1.6.0-linux-x86_64.tar.gz | tar -C /opt/julia-1.6 -x -z --strip-components=1 -f -

# COPY install-packages.jl /opt/julia-1.6/
# COPY sysimage-precompile.jl /opt/julia-1.6/

# USER $NB_USER

# ENV JULIA_DEPOT_PATH="/home/${NB_USER}/.julia"
# ENV JULIA_DEFAULT_ENV="${JULIA_DEPOT_PATH}/environments/v1.6"

# RUN mkdir -p $JULIA_DEFAULT_ENV

# COPY Project.toml $JULIA_DEFAULT_ENV
# COPY Manifest.toml $JULIA_DEFAULT_ENV

# USER root
# RUN chown -R $NB_USER $JULIA_DEFAULT_ENV /opt/julia-1.6
# USER $NB_USER

# RUN /opt/julia-1.6/bin/julia --threads 80 /opt/julia-1.6/install-packages.jl
# # RUN /opt/julia-1.6/bin/julia -e "using WebIO; WebIO.install_jupyter_serverextension()"
# RUN python3 -m pip install --upgrade webio_jupyter_extension

# RUN /opt/julia-1.6/bin/julia -e "using Pkg; Pkg.build(\"IJulia\")"
# RUN /opt/julia-1.6/bin/julia -e 'using PackageCompiler; create_sysimage([:Archimedes, :Plots, :Luxor, :NLsolve, :Unitful, :CoolProp, :BoundaryValueDiffEq, :PGFPlotsX, :LaTeXStrings, :TikzPictures, :IJulia, :Pluto]; precompile_statements_file="/opt/julia-1.6/sysimage-precompile.jl", replace_default=true, sysimage='./')'

# RUN mkdir -p $JULIA_DEPOT_PATH/config
# COPY startup.jl $JULIA_DEPOT_PATH/config

# ENV JULIA_DEPOT_PATH="${NOTEBOOK_DIR}/.julia_depot:${JULIA_DEPOT_PATH}"
# RUN /opt/julia-1.6/bin/julia -e "using Pkg; Pkg.status(); display(DEPOT_PATH)"

# RUN echo "c.MappingKernelManager.cull_idle_timeout = 1800" >> /home/${NB_USER}/.jupyter/jupyter_notebook_config.py
# RUN echo "c.NotebookApp.shutdown_no_activity_timeout = 1800" >> /home/${NB_USER}/.jupyter/jupyter_notebook_config.py

# RUN git clone https://github.com/pankgeorg/pluto-on-jupyterlab.git; \
#     pushd pluto-on-jupyterlab; \
#     pip3 install .; \
#     sed 's!julia!/opt/julia-1.6/bin/julia!' runpluto.sh | sed 's!import Pluto;!cd(joinpath(ENV[\\"HOME\\"], \\"work\\"));\nimport Pluto;!' > ../runpluto.sh; \
#     popd; \
#     rm -rf pluto-on-jupyterlab; \
#     echo PATH=/opt/julia-1.6/bin:$PATH >> .profile;

# RUN jupyter labextension install @jupyterlab/server-proxy
# RUN jupyter lab build

# # smoke test that it's importable at least
# RUN bash /usr/local/bin/start-singleuser.sh -h
# CMD ["bash", "/usr/local/bin/start-singleuser.sh"]

# -------------------
# FROM jupyter/scipy-notebook:latest

# USER root
# RUN wget https://julialang-s3.julialang.org/bin/linux/x64/1.5/julia-1.5.3-linux-x86_64.tar.gz && \
#     tar -xvzf julia-1.5.3-linux-x86_64.tar.gz && \
#     mv julia-1.5.3 /opt/ && \
#     ln -s /opt/julia-1.5.3/bin/julia /usr/local/bin/julia && \
#     rm julia-1.5.3-linux-x86_64.tar.gz

# USER ${NB_USER}

# COPY --chown=${NB_USER}:users ./plutoserver ./plutoserver
# COPY --chown=${NB_USER}:users ./environment.yml ./environment.yml
# COPY --chown=${NB_USER}:users ./setup.py ./setup.py
# COPY --chown=${NB_USER}:users ./runpluto.sh ./runpluto.sh

# RUN julia -e "import Pkg; Pkg.add([\"PlutoUI\", \"Pluto\", \"DataFrames\", \"CSV\", \"Plots\"]); Pkg.precompile()"

# RUN jupyter labextension install @jupyterlab/server-proxy && \
#     jupyter lab build && \
#     jupyter lab clean && \
#     pip install . --no-cache-dir && \
#     rm -rf ~/.cache

# EXPOSE 5000

# ENTRYPOINT ["jupyter", "lab","--ip=0.0.0.0","--allow-root"]

# We use a build stage to package binderhub and pycurl into a wheel which we
# then install by itself in the final image which is relatively slimmed.
ARG DIST=buster


# The build stage
# ---------------
FROM python:3.8-$DIST as build-stage
# ARG DIST is defined again to be made available in this build stage's scope.
# ref: https://docs.docker.com/engine/reference/builder/#understand-how-arg-and-from-interact
ARG DIST

# Install node as required to package binderhub to a wheel
RUN echo "deb http://deb.nodesource.com/node_14.x $DIST main" > /etc/apt/sources.list.d/nodesource.list \
 && curl -s https://deb.nodesource.com/gpgkey/nodesource.gpg.key | apt-key add -
RUN apt-get update \
 && apt-get install --yes \
        nodejs \
 && rm -rf /var/lib/apt/lists/*

# Copy the whole git repository to /tmp/binderhub
COPY . /tmp/binderhub
WORKDIR /tmp/binderhub

# Build the binderhub python library into a wheel and save it to the ./dist
# folder. There are no pycurl or ruamel.yaml.clib wheels so we build our own in
# the build stage.
RUN python -mpip install build && python -mbuild --wheel .
RUN pip wheel --wheel-dir ./dist \
       pycurl \
       ruamel.yaml.clib

# We download tini from here were we have wget available.
RUN ARCH=$(uname -m); \
    if [ "$ARCH" = x86_64 ]; then ARCH=amd64; fi; \
    if [ "$ARCH" = aarch64 ]; then ARCH=arm64; fi; \
    wget -qO /tini "https://github.com/krallin/tini/releases/download/v0.19.0/tini-$ARCH" \
 && chmod +x /tini

# The final stage
# ---------------
FROM python:3.8-slim-$DIST
WORKDIR /

# We use tini as an entrypoint to not loose track of SIGTERM signals as sent
# before SIGKILL when "docker stop" or "kubectl delete pod" is run. By doing
# that the pod can terminate very quickly.
COPY --from=build-stage /tini /tini
 
# The slim version doesn't include git as required by binderhub
RUN apt-get update \
 && apt-get install --yes \
        git \
 && rm -rf /var/lib/apt/lists/*

# Copy the built wheels from the build-stage. Also copy the image
# requirements.txt built from the binderhub package requirements.txt and the
# requirements.in file using the ./dependency script.
COPY --from=build-stage /tmp/binderhub/dist/*.whl pre-built-wheels/
COPY helm-chart/images/binderhub/requirements.txt .

# Install pre-built wheels and the generated requirements.txt for the image.
RUN pip install --no-cache-dir \
        pre-built-wheels/*.whl \
        -r requirements.txt

# When using the ./dependency script to output a frozen environment, we do it
# from within this container. So below we conditionally install pip-tools for
# use by the ./dependency script.
ARG PIP_TOOLS=
RUN test -z "$PIP_TOOLS" || pip install --no-cache pip-tools==$PIP_TOOLS

ENTRYPOINT ["/tini", "--", "python3", "-m", "binderhub"]
CMD ["--config", "/etc/binderhub/config/binderhub_config.py"]
ENV PYTHONUNBUFFERED=1
EXPOSE 5000