#!/bin/bash

[ "$DEBUG" = "true" ] && set -x

# If asked, we'll ensure that the www-data is set to the same uid/gid as the
# mounted volume.  This works around permission issues with virtualbox shared
# folders.
if [[ "$UPDATE_UID_GID" = "true" ]]; then
    echo "Updating www-data uid and gid"

    DOCKER_UID=`stat -c "%u" $MAGENTO_ROOT`
    DOCKER_GID=`stat -c "%g" $MAGENTO_ROOT`

    INCUMBENT_USER=`getent passwd $DOCKER_UID | grep -v www-data | cut -d: -f1`
    INCUMBENT_GROUP=`getent group $DOCKER_GID | grep -v www-data | cut -d: -f1`

    echo "Docker: uid = $DOCKER_UID, gid = $DOCKER_GID"
    echo "Incumbent: user = $INCUMBENT_USER, group = $INCUMBENT_GROUP"

    # Once we've established the ids and incumbent ids then we need to free them
    # up (if necessary) and then make the change to www-data.

    [ ! -z "${INCUMBENT_USER}" ] && usermod -u 99$DOCKER_UID $INCUMBENT_USER
    usermod -u $DOCKER_UID www-data

    [ ! -z "${INCUMBENT_GROUP}" ] && groupmod -g 99$DOCKER_GID $INCUMBENT_GROUP
    groupmod -g $DOCKER_GID www-data
fi

# Ensure our Magento directory exists
mkdir -p $MAGENTO_ROOT
chown www-data:www-data $MAGENTO_ROOT

<?php if ($flavour === 'cli'): ?>
CRON_LOG=/var/log/cron.log

# Setup Magento cron
echo "* * * * * www-data /usr/local/bin/php ${MAGENTO_ROOT}/bin/magento cron:run | grep -v \"Ran jobs by schedule\" >> ${MAGENTO_ROOT}/var/log/magento.cron.log" > /etc/cron.d/magento
echo "* * * * * www-data /usr/local/bin/php ${MAGENTO_ROOT}/update/cron.php >> ${MAGENTO_ROOT}/var/log/update.cron.log" >> /etc/cron.d/magento
echo "* * * * * www-data /usr/local/bin/php ${MAGENTO_ROOT}/bin/magento setup:cron:run >> ${MAGENTO_ROOT}/var/log/setup.cron.log" >> /etc/cron.d/magento

# Disable module imklog since container doesn't have permission to read that log
sed -i 's/^module.*imklog.*/#&/' /etc/rsyslog.conf

# Get rsyslog running for cron output
touch $CRON_LOG
echo "cron.* $CRON_LOG" > /etc/rsyslog.d/cron.conf
service rsyslog start

# Ensure Psy shell config folder is writable
mkdir -p /var/www/.config/psysh
chown www-data:www-data /var/www/.config/psysh
<?php endif ?>

# Configure Sendmail if required
if [ "$ENABLE_SENDMAIL" == "true" ]; then
    /etc/init.d/sendmail start
fi

# Substitute in php.ini values
[ ! -z "${PHP_MEMORY_LIMIT}" ] && sed -i "s/!PHP_MEMORY_LIMIT!/${PHP_MEMORY_LIMIT}/" /usr/local/etc/php/conf.d/zz-magento.ini
[ ! -z "${UPLOAD_MAX_FILESIZE}" ] && sed -i "s/!UPLOAD_MAX_FILESIZE!/${UPLOAD_MAX_FILESIZE}/" /usr/local/etc/php/conf.d/zz-magento.ini

FLAG=0
if [ "${PHP_ENABLE_XDEBUG_PROFILER}" == "true" ]; then
    FLAG=1
fi
sed -i "s/!PHP_ENABLE_XDEBUG_PROFILER!/${FLAG}/" /usr/local/etc/php/conf.d/zz-xdebug-settings.ini

FLAG=0
if [ "${PHP_ENABLE_XDEBUG_PROFILER_TRIGGER}" == "true" ]; then
    FLAG=1
fi
sed -i "s/!PHP_ENABLE_XDEBUG_PROFILER_TRIGGER!/${FLAG}/" /usr/local/etc/php/conf.d/zz-xdebug-settings.ini

mkdir -p "${MAGENTO_ROOT}/var/profiler"

[ "$PHP_ENABLE_XDEBUG" = "true" ] && \
    docker-php-ext-enable xdebug && \
    echo "Xdebug is enabled"

[ "$PHP_ENABLE_BLACKFIRE" = "true" ] && \
    docker-php-ext-enable blackfire && \
    echo "Black Fire is enabled"

<?php if ($flavour === 'cli'): ?>
# Configure composer
[ ! -z "${COMPOSER_GITHUB_TOKEN}" ] && \
    composer config --global github-oauth.github.com $COMPOSER_GITHUB_TOKEN

[ ! -z "${COMPOSER_MAGENTO_USERNAME}" ] && \
    composer config --global http-basic.repo.magento.com \
        $COMPOSER_MAGENTO_USERNAME $COMPOSER_MAGENTO_PASSWORD

[ ! -z "${COMPOSER_BITBUCKET_KEY}" ] && [ ! -z "${COMPOSER_BITBUCKET_SECRET}" ] && \
    composer config --global bitbucket-oauth.bitbucket.org $COMPOSER_BITBUCKET_KEY $COMPOSER_BITBUCKET_SECRET
<?php elseif ($flavour === 'fpm'): ?>
# Configure PHP-FPM
[ ! -z "${MAGENTO_RUN_MODE}" ] && sed -i "s/!MAGENTO_RUN_MODE!/${MAGENTO_RUN_MODE}/" /usr/local/etc/php-fpm.conf
[ ! -z "${FPM_PM_MAX_REQUESTS}" ] && sed -i "s/!FPM_PM_MAX_REQUESTS!/${FPM_PM_MAX_REQUESTS}/" /usr/local/etc/php-fpm.conf
<?php endif ?>

exec "$@"
