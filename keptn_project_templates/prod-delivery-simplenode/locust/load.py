from locust import HttpUser, between, task


class WebsiteUser(HttpUser):
    wait_time = between(5, 15)
    
    @task
    def index(self):
        self.client.get("/")

    @task
    def get_invoke(self):
        self.client.get("/api/invoke?url=https://www.keptn.sh")

    @task
    def get_echo(self):
        self.client.get("/api/echo?text=my echo text from locust")

    @task
    def get_version(self):
        self.client.get("/api/version")