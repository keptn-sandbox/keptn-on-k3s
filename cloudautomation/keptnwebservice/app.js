const EMPTY = "<EMPTY>";
var port = process.env.PORT || 8080,
    http = require('http'),
    fs = require('fs'),
	KEPTN_ENDPOINT = process.env.KEPTN_ENDPOINT || EMPTY,
	KEPTN_API_TOKEN = process.env.KEPTN_API_TOKEN || EMPTY
    finalHtml = fs.readFileSync('index.html').toString().replace("KEPTN_ENDPOINT", KEPTN_ENDPOINT).replace("KEPTN_ENDPOINT", KEPTN_ENDPOINT);


// collect request info
var requestCount = 0;
var requests = [];
var requestTrimThreshold = 5000;
var requestTrimSize = 4000;


// ======================================================================
// does some init checks and sets variables!
// ======================================================================
var init = function() {

	if (KEPTN_ENDPOINT == "" || KEPTN_ENDPOINT == null || KEPTN_ENDPOINT == "<EMPTY>") {
		console.log("Init: MISSING KEPTN_ENDPOINT!! Should be set to e.g: https://keptn.yourkeptn.com");
		process.exit(1)
	}
	if (KEPTN_API_TOKEN == "" || KEPTN_API_TOKEN == null || KEPTN_API_TOKEN == "<EMPTY>") {
		console.log("Init: MISSING KEPTN_API_TOKEN!!");
		process.exit(1)
	}

	console.log("KEPTN_ENDPOINT: " + KEPTN_ENDPOINT)
	console.log("KEPTN_API_TOKEN: " + KEPTN_API_TOKEN)
} 

// ======================================================================
// Background colors for our app depending on the build
// ======================================================================
var backgroundColors = ["#D6D4D2", "#73A53E", "#FF7C00", "#D3D309", "#4AB9D9"]
var getBackgroundColor = function() {
	var buildNumberForBackgroundColor = buildNumber;
	if(buildNumber == 0 || buildNumber > 4) buildNumberForBackgroundColor = 1;
	
	return backgroundColors[buildNumberForBackgroundColor];
}


// ======================================================================
// This is for logging
// ======================================================================
var logstream = fs.createWriteStream('./serviceoutput.log');
var SEVERITY_DEBUG = "Debug";
var SEVERITY_INFO = "Info";
var SEVERITY_WARNING = "Warning";
var SEVERITY_ERROR = "Error";

var log = function(severity, entry) {
	// console.log(entry);
	if (severity === SEVERITY_DEBUG) {
		console.log(entry)
		// dont log debug
	} else {
		var logEntry = new Date().toISOString() + ' - ' + severity + " - " + entry + '\n';
		// fs.appendFileSync('./serviceoutput.log', new Date().toISOString() + ' - ' + severity + " - " + entry + '\n');
		logstream.write(logEntry);
	}
};

var sendRequest = function(path, data, res) {

	try {

		var status = ""
		var returnStatusCode = 200;
		var http = null;
		var urlRequest = KEPTN_ENDPOINT;
		if(urlRequest.startsWith("https")) {
			http = require("https");
			urlRequest = urlRequest.replace("https://", "")
		}
		else {
			http = require("http");
			urlRequest = urlRequest.replace("http://", "")
		}
		closeResponse = false;
		var options = {
			host: urlRequest,
			method: "POST",
			path: path,
			headers: {
				'Content-Type': 'application/json',
				'Accept' : 'application/json',
				'x-token' : KEPTN_API_TOKEN,
				'Content-Length': data.length
			}		
		};
		log(SEVERITY_DEBUG, `Request: ${JSON.stringify(options)}` )
		const request = http.request(options, function(getResponse) {
			log(SEVERITY_DEBUG, `STATUS: ${getResponse.statusCode}` );
			log(SEVERITY_DEBUG, `HEADERS: ${JSON.stringify(getResponse.headers)}`);
			log(SEVERITY_DEBUG, `HOST: ${getResponse.host}` );

			// Buffer the body entirely for processing as a whole.
			var bodyChunks = [];
			getResponse.on('data', function(chunk) {
				bodyChunks.push(chunk);
			}).on('end', function() {
				var body = Buffer.concat(bodyChunks);
				log(SEVERITY_DEBUG, 'BODY: ' + body);
				status = body;
				res.writeHead(returnStatusCode, returnStatusCode == 200 ? 'OK' : 'ERROR', {'Content-Type': 'text/plain'});	
				res.write(status);
				res.end();
			}).on('error', function(error) {
				status = "Request failed: " + error;
				res.writeHead(returnStatusCode, returnStatusCode == 200 ? 'OK' : 'ERROR', {'Content-Type': 'text/plain'});	
				res.write(status);
				res.end();					
				log(SEVERITY_ERROR, status);
			}).on('uncaughtException', err => {
				status = "Request failed: " + error;
				res.writeHead(returnStatusCode, returnStatusCode == 200 ? 'OK' : 'ERROR', {'Content-Type': 'text/plain'});	
				res.write(status);
				res.end();					
				log(SEVERITY_ERROR, status);
			})
		});
		request.write(data);
		request.end()

	} catch(error) {
		status = "Request failed: " + error;
		res.writeHead(returnStatusCode, returnStatusCode == 200 ? 'OK' : 'ERROR', {'Content-Type': 'text/plain'});	
		res.write(status);
		res.end();					
		log(SEVERITY_ERROR, status);
	}

}

var triggerEvaluation = function(url, res) {
	var project = url.query["project"]
	var stage = url.query["stage"]
	var service = url.query["service"]
	var timeframe = url.query["timeframe"]
	var labelName1 = url.query["labelName1"]
	var labelValue1 = url.query["labelValue1"]
	var labelName2 = url.query["labelName2"]
	var labelValue2 = url.query["labelValue2"]

	const data = "{ \
		\"labels\": { " + 
			"\"" + labelName1 + "\" : \"" + labelValue1 + "\"," +
			"\"" + labelName2 + "\" : \"" + labelValue2 + "\"" +
		"}, " +
		"\"timeframe\": \"" + timeframe + "\"" + 
	    "}"

    log(SEVERITY_DEBUG, data)
	
	sendRequest('/api/controlPlane/v1/project/' + project + "/stage/" + stage + "/service/" + service + "/evaluation", data, res)
}

var triggerDelivery = function(url, res) {
	var project = url.query["project"]
	var stage = url.query["stage"]
	var service = url.query["service"]
	var image = url.query["image"]
	var sequence = url.query["sequence"]
	var labelName1 = url.query["labelName1"]
	var labelValue1 = url.query["labelValue1"]


	const data = "{ \
		\"data\": { \
			\"configurationChange\": { \
			  \"values\": { \
				\"image\": \"" + image + "\" \
			  } \
			}, \
		    \"labels\": { " + 
			  "\"" + labelName1 + "\" : \"" + labelValue1 + "\"" +
		    "}, " +
		    "\"project\": \"" + project + "\"," + 
		    "\"service\": \"" + service + "\"," + 
		    "\"stage\": \"" + stage + "\"" + 
		  "}, \
		\"source\": \"https://github.com/keptn-sandbox/keptn-on-k3s/cloudautomation\", \
		\"specversion\": \"1.0\", \
		\"type\": \"sh.keptn.event." + stage + "." + sequence + ".triggered\", \
		\"shkeptnspecversion\": \"0.2.3\" \
	  }"

	  log(SEVERITY_DEBUG, data)

/*	const data = JSON.stringify({
		"data": {
		  "configurationChange": {
			"values": {
			  "image": image
			}
		  },
		  "labels" : {
			  labelName1 : labelValue1
		  },
		  "project": project,
		  "service": service,
		  "stage": stage
		},
		"source": "https://github.com/keptn-sandbox/keptn-on-k3s/cloudautomation",
		"specversion": "1.0",
		"type": "sh.keptn.event." + stage + "." + sequence + ".triggered",
		"shkeptnspecversion": "0.2.3"
	  })*/
	
	  sendRequest('/api/v1/event', data, res)
}

// ======================================================================
// This is our main HttpServer Handler
// ======================================================================
var server = http.createServer(async function (req, res) {

	requests.push(Date.now());

	// now keep requests array from growing forever
	if (requests.length > requestTrimThreshold) {
		requests = requests.slice(0, requests.length - requestTrimSize);
	}

	try {

		if (req.url.startsWith("/api")) {
			var url = require('url').parse(req.url, true);

			log(SEVERITY_DEBUG, "Handling URL: " + url.pathname)

			// figure out which API call they want to execute
			if(url.pathname === "/api/triggerEvaluation") {
				triggerEvaluation(url, res)
			} else 
			if(url.pathname === "/api/triggerDelivery") {
				triggerDelivery(url, res)
			} else {
				res.writeHead(200, 'OK', {'Content-Type': 'text/plain'});	
				res.write("Unknown request!");
				res.end(); 
			}
		}
		else
		{
			res.writeHead(200, 'OK', {'Content-Type': 'text/html'});
			res.write(finalHtml);
			res.end();
		}
		
		requestCount++;
		if(requestCount >= 100) {
			log(SEVERITY_INFO, "Just served another 100 requests!");
			requestCount = 0;
		}
	} catch (error) {
		log(SEVERITY_ERROR, "Error: " + error)	
	}
});

process.on('uncaughtException', err => {
	console.error('There was an uncaught error', err)
	process.exit(1) //mandatory (as per the Node.js docs)
})

// first we initialize!
init();

// Listen on port 80, IP defaults to 127.0.0.1
server.listen(port);

// Put a friendly message on the terminal
console.log('Server running at http://127.0.0.1:' + port + '/');
log(SEVERITY_INFO, "Service is up and running - feed me with data!");