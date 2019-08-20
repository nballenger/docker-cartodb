# Single Container CartoDB, behind HTTPS

Instructions (assumes Linux or Mac OS):

1. Clone the repository.
1. Run `make install`. This will:
    1. Generate SSL certificate files (including a root signing authority) for the hostname `osscarto-single.localhost`.
    1. Generate configuration files for the various parts of the OSS Carto stack, in `docker/config`
    1. Generate scripts for building and interacting with a Docker image/container.
    1. Run the generated build script to create a Docker image named `osscarto-single:DEFAULT`
1. Add the file `docker/ssl/osscarto-singleCA.pem` to your machine's trusted certificate store.
1. Add the hostname `osscarto-single.localhost` to your `/etc/hosts` file:

    ```
    echo '127.0.0.1    osscarto-single.localhost' | sudo tee -a /etc/hosts
    ```

1. Run `make run`. This will start a container based on the built image.
1. Run `make shell`. This will give you a bash session on the running container.
1. On the container, run `ps aux`. You'll see a number of tasks running, but the web interface will only be available once the Rails server is running. To find the Rails server specifically, run `ps aux | grep thin` every few minutes until you see a line like:

    ```
    ruby2.5 /usr/local/bin/thin start --threaded -p 3000 -a 0.0.0.0 --threadpool-size 5
    ```

1. To use the web interface, load the following in a browser.

    ```
    https://osscarto-single.localhost
    ```

1. Log in with either of the valid credential sets:
    * `dev`/`pass1234`
    * `admin4example`/`pass1234`
