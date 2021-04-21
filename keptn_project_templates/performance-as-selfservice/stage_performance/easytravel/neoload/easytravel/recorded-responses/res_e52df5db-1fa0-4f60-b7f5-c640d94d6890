/**
 *  Asynchronous loading of journey recommendations.
 *
 * @author cwat-ceiching
 */


function showRecommendation()
{
    var pos = document.getElementById("recommendation");

    jQuery.ajax({
	    url: "CalculateRecommendations",
	    success: function(html) {
	    	pos.innerHTML = html;
	    },
	    async:true,
	    dataType: "html",
	    cache: false
	});
}

function createSpecialOffers()
{
	var pos = document.getElementById("recommendation");

    jQuery.ajax({
	    url: "CreateSpecialOffers",
	    success: function(html) {
	    	pos.innerHTML = html;
	    },
	    async:true,
	    dataType: "html",
	    cache: false
	});
}

function showRecommendationWait(interval)
{
	setTimeout(showRecommendation,interval);
}