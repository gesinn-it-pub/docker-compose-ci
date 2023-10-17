ARG MW_VERSION
ARG PHP_VERSION
FROM gesinn/mediawiki-ci:${MW_VERSION}-php${PHP_VERSION}

ARG EXTENSION
ARG COMPOSER_EXT
ARG NODE_JS
ARG MW_VERSION
ARG SMW_VERSION
ARG PHP_VERSION
ARG DT_VERSION
ARG PS_VERSION

ENV EXTENSION=${EXTENSION}

# get needed dependencies for this extension
RUN sed -i s/80/8080/g /etc/apache2/sites-available/000-default.conf /etc/apache2/ports.conf


RUN if [ ! -z "${SMW_VERSION}" ]; then \
        composer-require.sh mediawiki/semantic-media-wiki ${SMW_VERSION} && \
        echo 'wfLoadExtension( "SemanticMediaWiki" );\n' \
             'enableSemantics( $wgServer );\n' \
             >> __setup_extension__; \
    fi
RUN if [ ! -z "$PS_VERSION" ]; then \
        get-github-extension.sh PageSchemas ${PS_VERSION} && \
        echo 'wfLoadExtension( "PageSchemas" );\n' >> __setup_extension__; \
    fi
RUN if [ ! -z "$DT_VERSION" ]; then \
        get-github-extension.sh DisplayTitle ${DT_VERSION} && \
        echo 'wfLoadExtension( "DisplayTitle" );\n' >> __setup_extension__; \
    fi

RUN composer update 


RUN if [ ! -z "${SMW_VERSION}" ]; then \
        chown -R www-data:www-data /var/www/html/extensions/SemanticMediaWiki/; \
    fi

COPY composer*.json package*.json /var/www/html/extensions/$EXTENSION/

RUN if [[ ! -z "$COMPOSER_EXT"]] ; then cd extensions/$EXTENSION && composer update ; fi
RUN if [[ ! -z "$NODE_JS"]] ; then cd extensions/$EXTENSION && npm install ; fi

COPY . /var/www/html/extensions/$EXTENSION

RUN echo \
        "wfLoadExtension( '$EXTENSION' );\n" \
    >> __setup_extension__
