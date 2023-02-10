FROM ubuntu

# docker module metadata
LABEL module.name="cipa"
LABEL module.version="v0.0.1"

# Update package manager
RUN apt-get update

# Setup OS packages
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y \
    curl \
    git

# Install R
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y \
    r-base \
    r-base-dev

# Compile R Packages - CiPA
RUN Rscript -e 'install.packages(pkgs="https://cran.r-project.org/package=getopt&version=1.20.3", repos=NULL)'
RUN Rscript -e 'install.packages(pkgs="https://cran.r-project.org/package=optparse&version=1.6.6", repos=NULL)'
RUN Rscript -e 'install.packages(pkgs="https://cran.r-project.org/package=deSolve&version=1.28", repos=NULL)'
RUN Rscript -e 'install.packages(pkgs="https://cran.r-project.org/package=cmaes&version=1.0-11", repos=NULL)'

# Install CiPA
RUN git clone https://github.com/FDA/CiPA.git \
    && cd CiPA/hERG_fitting/models \
    && Rscript -e 'system("R CMD SHLIB hergmod.c")'
