ARG MW_VERSION
ARG PHP_VERSION
FROM gesinn/mediawiki-ci:${MW_VERSION}-php${PHP_VERSION}

ARG EXTENSION
ARG MW_INSTALL_PATH
ARG MW_VERSION
ARG PHP_VERSION
ARG PHP_EXTENSIONS
ARG OS_PACKAGES
ENV EXTENSION=${EXTENSION}
ENV MW_INSTALL_PATH=${MW_INSTALL_PATH}
ENV PHP_EXTENSIONS=${PHP_EXTENSIONS}
ENV OS_PACKAGES=${OS_PACKAGES}

# get needed dependencies for this extension
RUN sed -i s/80/8080/g /etc/apache2/sites-available/000-default.conf /etc/apache2/ports.conf

# get-ext.sh <Name> <version> [org/repo]: like get-github-extension.sh, but <version> may carry its own
# source repository as "org/repo@version"; an explicit third argument takes precedence
RUN printf '%s\n' \
    '#!/bin/bash' \
    'NAME=$1; VERSION=$2; REPO=$3' \
    'case "$VERSION" in' \
    '    *@*) REPO=${REPO:-${VERSION%%@*}}; VERSION=${VERSION#*@} ;;' \
    'esac' \
    'exec get-github-extension.sh "$NAME" "$VERSION" $REPO' \
    > /usr/local/bin/get-ext.sh && \
    chmod +x /usr/local/bin/get-ext.sh

### SemanticMediaWiki
ARG SMW_VERSION
RUN if [ -n "${SMW_VERSION}" ]; then \
    composer-require.sh mediawiki/semantic-media-wiki "${SMW_VERSION}" && \
    SMW_MAJOR=$(echo "${SMW_VERSION}" | cut -d. -f1) && \
    if [ "${SMW_VERSION}" = "dev-master" ] || [ "${SMW_MAJOR}" -ge 7 ] 2>/dev/null; then \
        printf '%s\n' \
            'wfLoadExtension( "SemanticMediaWiki" );' \
            >> __setup_extension__; \
    else \
        printf '%s\n' \
            'wfLoadExtension( "SemanticMediaWiki" );' \
            '// require ConfigPreloader until https://github.com/SemanticMediaWiki/SemanticMediaWiki/issues/6450 is fixed' \
            'require_once "$IP/extensions/SemanticMediaWiki/src/ConfigPreloader.php";' \
            'enableSemantics( $wgServer );' \
            >> __setup_extension__; \
    fi; \
fi
### SemanticMediaWiki

### PageForms
ARG PF_VERSION
ARG PF_REPO
RUN if [ ! -z "${PF_VERSION}" ]; then \
        get-ext.sh PageForms ${PF_VERSION} ${PF_REPO} && \
        echo 'wfLoadExtension( "PageForms" );\n' >> __setup_extension__; \
    fi
### PageForms

### PageSchemas
ARG PS_VERSION
RUN if [ ! -z "${PS_VERSION}" ]; then \
        get-ext.sh PageSchemas ${PS_VERSION} && \
        echo 'wfLoadExtension( "PageSchemas" );\n' >> __setup_extension__; \
    fi
### PageSchemas

### DisplayTitle
ARG DT_VERSION
RUN if [ ! -z "${DT_VERSION}" ]; then \
        get-ext.sh DisplayTitle ${DT_VERSION} && \
        echo 'wfLoadExtension( "DisplayTitle" );\n' >> __setup_extension__; \
    fi
### DisplayTitle

### AdminLinks
ARG AL_VERSION
RUN if [ ! -z "${AL_VERSION}" ]; then \
        get-ext.sh AdminLinks ${AL_VERSION} && \
        echo 'wfLoadExtension( "AdminLinks" );\n' >> __setup_extension__; \
    fi
### AdminLinks

### ApprovedRevs
ARG AR_VERSION
RUN if [ ! -z "${AR_VERSION}" ]; then \
        get-ext.sh ApprovedRevs ${AR_VERSION} && \
        echo 'wfLoadExtension( "ApprovedRevs" );\n' >> __setup_extension__; \
    fi
### ApprovedRevs

### Maps
ARG MAPS_VERSION
RUN if [ ! -z "${MAPS_VERSION}" ]; then \
        composer-require.sh mediawiki/maps ${MAPS_VERSION} && \
        echo 'wfLoadExtension( "Maps" );\n' >> __setup_extension__; \
    fi
### Maps

### SemanticResultFormats
ARG SRF_VERSION
RUN if [ ! -z "${SRF_VERSION}" ]; then \
        composer-require.sh mediawiki/semantic-result-formats ${SRF_VERSION} && \
        echo 'wfLoadExtension( "SemanticResultFormats" );\n' >> __setup_extension__; \
    fi
### SemanticResultFormats

### Mermaid
ARG MM_VERSION
RUN if [ ! -z "${MM_VERSION}" ]; then \
        composer-require.sh mediawiki/mermaid ${MM_VERSION} && \
        echo 'wfLoadExtension( "Mermaid" );\n' >> __setup_extension__; \
    fi
### Mermaid

### Lingo
ARG LINGO_VERSION
RUN if [ ! -z "${LINGO_VERSION}" ]; then \
        composer-require.sh mediawiki/lingo ${LINGO_VERSION} && \
        echo 'wfLoadExtension( "Lingo" );\n' >> __setup_extension__; \
    fi
### Lingo

### Scribunto
ARG SCRIBUNTO_VERSION
RUN if [ ! -z "${SCRIBUNTO_VERSION}" ]; then \
        get-ext.sh Scribunto ${SCRIBUNTO_VERSION} && \
        echo 'wfLoadExtension( "Scribunto" );\n' >> __setup_extension__; \
    fi
### Scribunto

### Echo
ARG ECHO_VERSION
RUN if [ ! -z "${ECHO_VERSION}" ]; then \
        get-ext.sh Echo ${ECHO_VERSION} && \
        echo 'wfLoadExtension( "Echo" );\n' >> __setup_extension__; \
    fi
### Echo

### chameleon
ARG CHAMELEON_VERSION
RUN if [ -n "${CHAMELEON_VERSION}" ]; then \
    composer-require.sh mediawiki/chameleon-skin "${CHAMELEON_VERSION}" && \
    printf '%s\n' \
        "wfLoadExtension( 'Bootstrap' );" \
        "wfLoadSkin( 'chameleon' );" \
        "\$wgDefaultSkin='chameleon';" \
        >> __setup_extension__; \
fi
### chameleon

RUN composer update 

COPY . /var/www/html/extensions/$EXTENSION

RUN if [ ! -z "${SMW_VERSION}" ] || [ "${EXTENSION}" = "SemanticMediaWiki" ]; then \
        chown -R www-data:www-data /var/www/html/extensions/SemanticMediaWiki/; \
    fi

ARG OS_PACKAGES
RUN if [ ! -z "${OS_PACKAGES}" ] ; then apt-get update && apt-get install -y $OS_PACKAGES ; fi

ARG PHP_EXTENSIONS
RUN if [ ! -z "${PHP_EXTENSIONS}" ] ; then docker-php-ext-install $PHP_EXTENSIONS ; fi

ARG COMPOSER_EXT
RUN if [ ! -z "${COMPOSER_EXT}" ] ; then cd extensions/$EXTENSION && composer update ; fi

ARG NODE_JS
RUN if [ ! -z "${NODE_JS}" ] ; then cd extensions/$EXTENSION && npm install ; fi

ARG BROWSER_TESTS
RUN if [ ! -z "${BROWSER_TESTS}" ] ; then \
        cd extensions/$EXTENSION && \
        npm install --no-save playwright && \
        npx playwright install --with-deps chromium ; \
    fi

# special handling for testing SMW itself
RUN if [ "${EXTENSION}" = "SemanticMediaWiki" ]; then \
        COMPOSER=composer.local.json composer require --no-update --working-dir ${MW_INSTALL_PATH} mediawiki/semantic-media-wiki @dev && \
        COMPOSER=composer.local.json composer config repositories.semantic-media-wiki '{"type": "path", "url": "extensions/SemanticMediaWiki"}' --working-dir ${MW_INSTALL_PATH} && \
        composer update --working-dir ${MW_INSTALL_PATH}; \
    fi

RUN echo \
        "wfLoadExtension( '$EXTENSION' );\n" \
    >> __setup_extension__

COPY *__setup_extension__ setup_extension

RUN if [ -f setup_extension ]; then \
        cat setup_extension >> __setup_extension__; \
    fi

### custom extensions (extensions.local.json in the project root, optional)
COPY extensions.local.json* /tmp/
# the token for extensions with "private": true is read from /run/secrets/GH_API_TOKEN; it is only mounted
# for this step and not part of the image. Without a token the secret is empty; the build then stops
# with a clear message instead of failing in the download of the private extension.
RUN --mount=type=secret,id=GH_API_TOKEN \
    if command -v install-extensions.sh > /dev/null 2>&1; then \
        if grep -Eq '"private"[[:space:]]*:[[:space:]]*true' /tmp/extensions.local.json 2>/dev/null \
                && [ ! -s /run/secrets/GH_API_TOKEN ]; then \
            echo "extensions.local.json contains an extension with \"private\": true, but GH_API_TOKEN is not set." >&2; \
            echo "Set GH_TOKEN_<GIT_USER_NAME> or GH_API_TOKEN in the environment of make." >&2; \
            exit 1; \
        fi; \
        install-extensions.sh /tmp/extensions.local.json; \
    fi
# An extensions.local.json below extensions/ is not an extension registration, but the PHPUnit bootstrap of
# MediaWiki 1.39 loads every extensions/*/extension*.json and stops with "attempted to load twice" when there
# are two. One is the copy of the project root made above, another one comes with extensions that ship their own
# (PageForms does). The file was consumed above, so none of them is needed in the image.
RUN rm -f ${MW_INSTALL_PATH}/extensions/*/extensions.local.json
### custom extensions
