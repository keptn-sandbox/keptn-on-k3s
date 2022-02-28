from locust import HttpUser, between, task
import uuid

class SimpleNodeLocustUser(HttpUser):
    wait_time = between(5, 15)

    def on_start(self):
        self.script_name = "load.py"
        self.test_name = "SimpleNodeLocustUser"
        self.userId = str(uuid.uuid4())
    
    def setDynatraceHeader(self, stepName):
        headerValue = "LSN=" + self.script_name + ";TSN=" + stepName + ";LTN=" + self.test_name + ";VU=" + self.userId 
        self.client.headers = { "x-dynatrace-test" : headerValue }

    @task
    def index(self):
        self.setDynatraceHeader("Home")
        self.client.get("/")

    @task(3)
    def get_invoke(self):
        self.setDynatraceHeader("Invoke")
        self.client.get("/api/invoke?url=https://www.keptn.sh")

    @task
    def get_echo(self):
        self.setDynatraceHeader("Echo")
        self.client.get("/api/echo?text=my echo text from locust")

    @task
    def get_version(self):
        self.setDynatraceHeader("Version")
        self.client.get("/api/version")