// declare dynaTrace with the use of init time (load time) branching
var emptyFunction = function() {
	if (typeof dT_ === 'undefined') {
		if (typeof console !== 'undefined') {
			console.warn('JavaScript agent is not injected')
		}
	} else {
		if (typeof console !== 'undefined') {
			console.warn('You called a JS API function which is not available in the version you use.')
		}
	}
};
var originalApi = null;
var rumapi = {
	actionName : emptyFunction,
	addPageLeavingListener : emptyFunction,
	addStreamingNode: emptyFunction,
	beginUserInput : emptyFunction,
	endUserInput : emptyFunction,
	endVisit: emptyFunction,
	enterAction: emptyFunction,
	enterXhrAction : emptyFunction,
	enterXhrCallback: emptyFunction,
	incrementOnLoadEndMarkers: emptyFunction,
	leaveAction: emptyFunction,
	leaveXhrAction: emptyFunction,
	leaveXhrCallback: emptyFunction,
	reportError: emptyFunction,
	reportEvent: emptyFunction,
	reportString: emptyFunction,
	reportValue: emptyFunction,
	reportWarning: emptyFunction,
	sendSignal: emptyFunction,
	setAppVersion: emptyFunction,
	setAutomaticActionDetection: emptyFunction,
	setLoadEndManually: emptyFunction,
	setMetaData: emptyFunction,
	signalLoadEnd: emptyFunction,
	signalLoadStart: emptyFunction,
	signalOnLoadEnd: emptyFunction,
	signalOnLoadStart: emptyFunction,
	startThirdParty: emptyFunction,
	stopThirdParty: emptyFunction,
	tagVisit: emptyFunction
}

if (typeof dtrum !== 'undefined') {
	originalApi = dtrum;
	
	rumapi.actionName = dtrum.actionName;
	rumapi.tagVisit = dtrum.identifyUser;
	rumapi.endVisit = dtrum.endSession;
	
} else if (typeof ruxitApi !== 'undefined') {
	originalApi = ruxitApi;
	
	rumapi.actionName = ruxitApi.actionName;
	rumapi.tagVisit = ruxitApi.tagSession;
	rumapi.endVisit = ruxitApi.endSession;
	
} else if (typeof dynaTrace !== 'undefined') {
	originalApi = dynaTrace;
	
	rumapi.tagVisit = dynaTrace.tagVisit;
	rumapi.addStreamingNode = dynaTrace.addStreamingNode;
	rumapi.reportString = dynaTrace.reportString;
	rumapi.reportValue = dynaTrace.reportValue;
	rumapi.setAppVersion = dynaTrace.setAppVersion;
	rumapi.setMetaData = dynaTrace.setMetaData;
}

// Set the functions which are called the same on both APIs:
if (originalApi != null) {
	for (var property in rumapi) {
		if (rumapi.hasOwnProperty(property) && rumapi[property] === emptyFunction && originalApi[property]) {
			rumapi[property] = originalApi[property];
		}
	}
}
