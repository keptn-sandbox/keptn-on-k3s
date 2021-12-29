from locust import HttpUser, between, task
import uuid

class SimpleNodeLocustUser(HttpUser):
    wait_time = between(5, 15)

    def on_start(self):
        self.locust.script_name = "load.py"
        self.locust.test_name = "SimpleNodeLocustUser"
        self.locust.userId = str(uuid.uuid4())
    
    def setDynatraceHeader(self, stepName):
        headerValue = "LSN=" + self.locust.script_name + ";TSN=" + stepName + ";LTN=" + self.locust.test_name + ";VU=" + self.locust.userId 
        self.client.headers = { "x-dynatrace-test" : headerValue }

    @task
    def index(self):
        self.setDynatraceHeader(self, "Home")
        self.client.get("/")

    @task(3)
    def get_invoke(self):
        self.setDynatraceHeader(self, "Invoke")
        self.client.get("/api/invoke?url=https://www.keptn.sh")

    @task
    def get_echo(self):
        self.setDynatraceHeader(self, "Echo")
        self.client.get("/api/echo?text=my echo text from locust")

    @task
    def get_version(self):
        self.setDynatraceHeader(self, "Version")
        self.client.get("/api/version")