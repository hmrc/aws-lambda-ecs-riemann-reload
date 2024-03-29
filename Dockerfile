ARG PYTHON_VERSION=3.8
FROM python:${PYTHON_VERSION}

ARG APP_USER=jenkins
ARG APP_USER_ID=1000
ARG APP_GROUP_ID=1000
ARG PROJECT_ROOT=/src/
ARG POETRY_VERSION=1.1.6

# setup
RUN apt-get update && apt-get install -y \
	build-essential \
	libssl-dev \
	libffi-dev \
	make \
	bash \
	zip \
	openssl \
	git

# create app dir and user
RUN mkdir -p ${PROJECT_ROOT} && \
    addgroup --gid ${APP_GROUP_ID} ${APP_USER} && \
    adduser --system --uid ${APP_USER_ID} ${APP_USER} --gid ${APP_GROUP_ID} --disabled-password

# set local directory
WORKDIR ${PROJECT_ROOT}

# upgrade pip and install poetry
RUN pip install --upgrade pip && \
    pip install poetry==${POETRY_VERSION}

# change permissions on our src and home directories so that our user has access
RUN chown -R ${APP_USER}:${APP_USER} ${PROJECT_ROOT} && chown -R ${APP_USER}:${APP_USER} /home/${APP_USER}

# change to our non root user for security purposes
USER ${APP_USER}
