ARG MW_VERSION
ARG PHP_VERSION
FROM gesinn/mediawiki-ci:${MW_VERSION}-php${PHP_VERSION}

ARG MW_VERSION
ARG SMW_VERSION
ARG PHP_VERSION
ARG DT_VERSION
ARG PS_VERSION

# get needed dependencies for this extension
RUN sed -i s/80/8080/g /etc/apache2/sites-available/000-default.conf /etc/apache2/ports.conf


RUN if [ ! -z "${SMW_VERSION}" ]; then \
        composer-require.sh mediawiki/semantic-media-wiki ${SMW_VERSION} && \
        echo 'wfLoadExtension( "SemanticMediaWiki" );\n' \
             'enableSemantics( $wgServer );\n' \
             >> __setup_extension__; \
    fi
RUN if [ ! -z "$DT_VERSION" ]; then \
        composer-require.sh mediawiki/semantic-media-wiki ${SMW_VERSION} && \
        echo 'wfLoadExtension( "PageSchemas" );\n' >> __setup_extension__; \
    fi
RUN if [ ! -z "$PS_VERSION" ]; then \
        composer-require.sh mediawiki/semantic-media-wiki ${SMW_VERSION} && \
        echo 'wfLoadExtension( "DisplayTitle" );\n' >> __setup_extension__; \
    fi

RUN composer update 

# IF
RUN chown -R www-data:www-data /var/www/html/extensions/SemanticMediaWiki/

ENV EXTENSION=PageForms
COPY composer*.json package*.json /var/www/html/extensions/$EXTENSION/

RUN cd extensions/$EXTENSION && composer update && npm install

COPY . /var/www/html/extensions/$EXTENSION

RUN echo \
        'wfLoadExtension( "SemanticMediaWiki" );\n' \
        'enableSemantics( $wgServer );\n' \
        'wfLoadExtension( "PageSchemas" );\n' \
        'wfLoadExtension( "DisplayTitle" );\n' \
        "wfLoadExtension( '$EXTENSION' );\n" \
    >> __setup_extension__
