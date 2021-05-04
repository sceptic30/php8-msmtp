# Php8 With SMTP Support Using MSMTP
This Dockerfile will build a Php docker image with msmtp installed and configured.
## Buid Steps
1. ### Clone the repository
   1. git clone https://github.com/sceptic30/php8-msmtp.git
   2. cd php8-msmtp
   3. docker build . -t your_image_tag
   
2. ### Create configuration files for msmtp
   1. mkdir msmtp && touch msmtp/msmtprc
   2. touch msmtp/aliases

3. ### Populate the configuration files with your smtp server details
   Please note that the current username and password will be deleted, and replaced with your provided credentials.
   1. **msmtprc**:
   ``` # Set default values for all following accounts.
        defaults
        auth           on
        tls            on
        tls_trust_file /etc/ssl/certs/ca-certificates.crt
        syslog         on
        # My SMTP Server
        account        myprivateserver
        host           mail.mydomain.com
        port           587
        from           myuser@mydomain.com
        user           myuser@mydomain.com
        password       your_pass_word
    ```
    1. **aliases**:
   ``` # Set default values for all following accounts.
        root: myuser@mydomain.com
        default: myuser@mydomain.com
    ```
4. ### Bind-mount config folder to php docker container
   A php docker-compose file would look like this:
   ```
   version: '3.3'

   services:
    php:
        image: admintuts/php:8.0.5-fpm-alpine
        container_name: php
        hostname: php
        restart: unless-stopped
        volumes:
         - ./html-public:/var/www/html
         - ./php-conf/php.ini:/usr/local/etc/php/php.ini
         - ./msmtp/msmtprc:/etc/msmtprc
         - ./msmtp/aliases:/etc/aliases
        networks:
         - default
    volumes:
        html-public:
        php-conf:
        msmtp:
    networks:
        default:
            driver: bridge
    ```
   > ***html-public*** is your webserver bind-mounted folder.
   > ***php-conf*** contains a php.ini file also bind-mounted.
   > ***msmtp** is the folder created in step 2.
   
   A WordPress docker-compose file would look like this:
   ```
   version: '3.3'

   services:
    wordpress:
        depends_on:
            - your-db-service
        image: admintuts/wordpress:php7.4.18-fpm-redis-alpine
        container_name: wordpress
        hostname: wordpress
        restart: unless-stopped
        env_file: variables/wordpress.env
        volumes:
            - ./wordpress-data:/var/www/html
            - ./php-conf/php.ini:/usr/local/etc/php/php.ini:ro
            - ./msmtp/msmtprc:/etc/msmtprc
            - ./msmtp/aliases:/etc/aliases
    networks:
        default:
            driver: bridge
    ```
5. ### Send A Test E-Mail
    1. ssh to the running container ``` docker exec -it php sh ```
    2. And run the command: ```printf "To: recipient@gmail.com \nFrom: mymyuser@mydomain.com \nSubject: Email Test Using MSMTP \nHello there. This is email test from MSMTP." | msmtp recipient@gmail.com ```
    > If you have configure your smtp server correctly with DKIM and DMARC, running the command above will send this test email straight to recipient's inbox. In the case that **To** and **From** fields are not send correctly, then the email will go to spam folder.
