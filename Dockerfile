ARG MW_VERSION
ARG PHP_VERSION
FROM gesinn/mediawiki-ci:${MW_VERSION}-php${PHP_VERSION}

ARG EXTENSION
ARG MW_INSTALL_PATH
ARG MW_VERSION
ARG PHP_VERSION
ARG PHP_EXTENSIONS
ENV EXTENSION=${EXTENSION}
ENV MW_INSTALL_PATH=${MW_INSTALL_PATH}
ENV PHP_EXTENSIONS=${PHP_EXTENSIONS}

# get needed dependencies for this extension
RUN sed -i s/80/8080/g /etc/apache2/sites-available/000-default.conf /etc/apache2/ports.conf

### SemanticMediaWiki
ARG SMW_VERSION
RUN if [ ! -z "${SMW_VERSION}" ]; then \
        composer-require.sh mediawiki/semantic-media-wiki ${SMW_VERSION} && \
        echo 'wfLoadExtension( "SemanticMediaWiki" );\n' \
             'enableSemantics( $wgServer );\n' \
             >> __setup_extension__; \
    fi
### SemanticMediaWiki

### PageForms
ARG PF_VERSION
ARG PF_REPO
RUN if [ ! -z "${PF_VERSION}" ]; then \
        get-github-extension.sh PageForms ${PF_VERSION} ${PF_REPO} && \
        echo 'wfLoadExtension( "PageForms" );\n' >> __setup_extension__; \
    fi
### PageForms

### PageSchemas
ARG PS_VERSION
RUN if [ ! -z "${PS_VERSION}" ]; then \
        get-github-extension.sh PageSchemas ${PS_VERSION} && \
        echo 'wfLoadExtension( "PageSchemas" );\n' >> __setup_extension__; \
    fi
### PageSchemas

### DisplayTitle
ARG DT_VERSION
RUN if [ ! -z "${DT_VERSION}" ]; then \
        get-github-extension.sh DisplayTitle ${DT_VERSION} && \
        echo 'wfLoadExtension( "DisplayTitle" );\n' >> __setup_extension__; \
    fi
### DisplayTitle

### AdminLinks
ARG AL_VERSION
RUN if [ ! -z "${AL_VERSION}" ]; then \
        get-github-extension.sh AdminLinks ${AL_VERSION} && \
        echo 'wfLoadExtension( "AdminLinks" );\n' >> __setup_extension__; \
    fi
### AdminLinks

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

### chameleon
ARG CHAMELEON_VERSION
RUN if [ ! -z "${CHAMELEON_VERSION}" ]; then \
        composer-require.sh mediawiki/chameleon-skin ${CHAMELEON_VERSION} && \
        echo "wfLoadExtension( 'Bootstrap' );\n" \
             "wfLoadSkin( 'chameleon' );\n" \
             "\$wgDefaultSkin='chameleon';\n" \ >> __setup_extension__; \
    fi
### chameleon

RUN composer update 


RUN if [ ! -z "${SMW_VERSION}" ]; then \
        chown -R www-data:www-data /var/www/html/extensions/SemanticMediaWiki/; \
    fi

COPY . /var/www/html/extensions/$EXTENSION

ARG PHP_EXTENSIONS
RUN if [ ! -z "${PHP_EXTENSIONS}" ] ; then docker-php-ext-install -j $PHP_EXTENSIONS ; fi

ARG COMPOSER_EXT
RUN if [ ! -z "${COMPOSER_EXT}" ] ; then cd extensions/$EXTENSION && composer update ; fi

ARG NODE_JS
RUN if [ ! -z "${NODE_JS}" ] ; then cd extensions/$EXTENSION && npm install ; fi


RUN echo \
        "wfLoadExtension( '$EXTENSION' );\n" \
    >> __setup_extension__

COPY *__setup_extension__ setup_extension

RUN if [ -f setup_extension ]; then \
        cat setup_extension >> __setup_extension__; \
    fi
