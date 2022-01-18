# Running Locally

1. Once you clone the repo, you need to run npm install to download the required modules. I used npm: `7.5.0`, node: `15.8.0`

    ```
    npm update
    npm start
    ```

1. Set these environment variables

    ```
    export KEPTN_ENDPOINT=[YOUR URL]
    export KEPTN_API_TOKEN=[YOUR-TOKEN]
    ```

1. Run the application 

    ```
    npm start
    ```

1. Access the application @ http://127.0.0.1:8080/

# Running as docker container

I have uploaded the following versions to my dockerhub registry:

| Image | Description |
| ------ | ------------- |
| grabnerandi/keptnwebservice:1.0.0 | Initial Version |
| grabnerandi/keptnwebservice:2.0.0 | Version with better UI and Manage Resource support |
| grabnerandi/keptnwebservice:2.0.1 | Allows requests to https without a valid certificate |