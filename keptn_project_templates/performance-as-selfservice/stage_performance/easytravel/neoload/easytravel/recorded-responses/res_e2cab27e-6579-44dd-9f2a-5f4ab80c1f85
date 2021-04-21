/**
 * @author cwat-cchen
 * 
 * Building a 5 star rating system with jQuery and PHP.
 * Users can rate their journey, leave comments and see journey ratings and reviews 
 * which they plan to go
 * 
 */

    /***
     * limit the number of characters a user can type in a textbox 
     */
    function limitText(limitField, limitCount, limitNum) {
	    if (limitField.value.length > limitNum) {
		    limitField.value = limitField.value.substring(0, limitNum);
	    } else {
		    limitCount.value = limitNum - limitField.value.length;
	    }
    }

    /**
     * get and format the current date
     */
    function getCurrentDate() {
	    var today = new Date();
	    var day = today.getDate();
		var month = today.getMonth()+1;
		var year = today.getFullYear();
		var hour = today.getHours();
		var min = today.getMinutes();
		var sec = today.getSeconds();
		
		if(day < 10) {
			dd = '0' + day;
		}
		
		if(month < 10) {
			month ='0' + month;
		}
		
		today = year + '-' + month + '-' + day + ' ' + hour + ':' + min + ':' + sec;
		
		return today;
	
	}

	/**
	 * query the server and get some information on every vote widget on the page,
	 * params contains the information we want to send to the server
	 */
    $(function() {
    	 $('.tripDetailsPanel .rate_widget, .bookReviewBox .rate_widget').each(function() {
      	   getAverageTotal($(this));
         });
       
       $('.mainTextBox .rate_widget, .ratingBox .rate_widget').each(function() { 
    			   
    	 showstar($(this));
    	 fillData($(this));  
    	   
       });
              
       /**
        * show the rating details and comments
        */ 
       $('.ratingTextBox .journeyID').each(function() {
    	   getRatingDetailHTML($(this));  
    	   getCommentDetailHTML($(this));
        });
       
       /**
        * This actually records the vote
        */
       $('.ratings_stars').click(function() {	
           var star = this;
           var widget = $(this).parent();
           var clicked_data = {
               clicked_on : $(star).attr('class'),
               journey_id : $(star).parent().attr('rel')
           };
           
           $.post(
               'rating/ratings.php',
               clicked_data,
               function(data) {
               	 set_votes(widget,data);	
               },
               'json'
           ); 
                   
       });   
       
       /**
        * when users submit comments, add comments to MySql
        */
       $('form').submit(function() {
    		var username = $('#username span').text();
    		var journeyId = $('#journeyID').text();
    		var text = $('textarea').val();
            var today = getCurrentDate();
    		    		
    		if (text == "")
    			alert("Feel free to write down your suggestion!");
    		
    		if(username != "" && text != "") {
    			
    			var params = {
    			user_name : username,
    			journey_id : journeyId,
    			comment : text,
    			date: today,
                insert: 1	
    			};
    			
    			 var callback = function(data) {
    		            alert(data);
    		        };
    			useGuestbook(params,callback);
    			
    		}
    		
    	 });
           
    });
    
    /**
     * get the journey ratings
     * @param widget
     */
    function fillData(widget) {
        var params = {
            journey_id : widget.attr('rel'),
            fetch: 1
        };
        var callback = function(data) {
            set_votes(widget,data);
        };
        loadRatings(widget,params, callback);
    }
    
    /**
     * return its HTML code and show the rating details
     * @param widget
     */
    function getRatingDetailHTML(widget) {
         var journeyid = widget.attr('rel')   
        
    	 var params = {
             journey_id : journeyid,
             diff: 1
        };
        
    	 var callback = function(detail) {
    		 var detail = detail.ratings;
    	     log("detail: " + detail);
             setRatingDetails(journeyid, detail);
        };
        
        loadRatings(widget,params, callback);
    }   
    
    /**
     * return its HTML code and show comments
     * @param widget
     */
    function getCommentDetailHTML(widget) {
    	 var journeyid = widget.attr('rel')  
    	 
  	     var params = {
     	    journey_Id : journeyid ,
     	    action: "get_rows"
     	};
         
         var callback = function(data) {
       	 var comment = data.comment;
            setGuestbookComments(journeyid, comment);
            getPagination(journeyid);
           
         };
 	    
         useGuestbook(params,callback);
    }
    
    
    /**
     * get the average rating of each journey which contains
     * staff, services, clean, comfort, value for money, location
     * @param widget
     */
    function getAverageTotal(widget) {
        var params = {
        	journey_id : widget.attr('rel'),
            info: 1
        };
        var callback = function(data) {
            set_totalAvgRating(widget,data);
        };
        loadRatings(widget,params, callback);
    }
    
    function loadRatings(widget,params, callback) {
        $.post(
            'rating/ratings.php',
            params,
            callback,
            'json'
        );
    }
   
    function  useGuestbook(params, callback){
	    $.post(
	        'rating/guestbook.php',
	         params,
	         callback,
	         'json'
	     ); 
    }
    
    function setRatingDetails(journeyid, detail) {
    	log('journeyid:' + journeyid);
        $('#details').html(detail);
           
    }
    
    function setGuestbookComments(journeyid, comment) {
    	 log('journeyid:' + journeyid);
    	 log('result:' + comment);
         $('#content').html(comment);
            
    }
    
    /**
     * display users' comments with pagination
     * @param journeyid
     */
    function getPagination(journeyid) {
    	
      var params = {
          journey_Id : journeyid ,
          action: "row_count"
      };
               
      var callback = function(data) {
          var count = data.count;
          var limit = data.limit;
          log('count--:' + count);
          
          $('#page_count').val(Math.ceil(count/limit));
          generateRows(journeyid, 1);
      };
      
      useGuestbook(params,callback);
      
    }
    
    function generateRows(journeyid, selected) {
    	var pages = $('#page_count').val();
    	var link="";
    	log('pages:' + pages);
    	log('selected:' + selected);
    	
    	if(pages != 0 && selected == 1 ) {
    		$("#content").after("<br /><div id='paginator'>");
    		for(i=0; i<pages; i++) {
    		    if(i==0) {
        	        link += "<a href='#' class='pagor selected'>" + (i+1) + "</a>";	
    		    }else {
    		        link += "<a href='#' class='pagor'>" + (i+1) + "</a>";	
    		    }
    		}
    		log('link: '+ link);
		    $("#content").after(link + "<div style='clear:both;'></div></div>");
		    
		    $(".pagor").click(function() {
	            var index = $(".pagor").index(this);               
                var params = {
          		    journey_Id : journeyid ,
          		    action: "get_rows",
          		    start: index
          		};
          		          
          		var callback = function(data) {
          		    var comment = data.comment;
          		    setGuestbookComments(journeyid, comment);
          		   
          		}; 	    
          		useGuestbook(params,callback);
          		
          		$('.pagor').removeClass("selected");
       		    $(this).addClass("selected");
                
		    });
    	} else {    	
    			if(pages != 0) {
	    		    var pagers = "<div id='paginator'>";
	    			for (i = 1; i <= pages; i++) {
	    				if (i == selected) {
	    					pagers += "<a href='#' class='pagor selected'>" + i + "</a>";
	    				} else {
	    					pagers += "<a href='#' class='pagor'>" + i + "</a>";
	    				}				
	    			}
	    			
	    			pagers += "<div style='float:left;padding-left:6px;padding-right:6px;'>...</div><a href='#' class='pagor'>" + Number(pages) + "</a><div style='clear:both;'></div></div>";
	                
	    			$("#paginator").remove();
	    			$("#content").after(pagers);
    			}	
    	}
    }
    
    /**
     * show stars in the rating-action page. Users can easily rate each item
     */
    function showstar(widget) {
    	log(widget);
    	// add mouseover and mouseout handlers for the stars
    	$('.ratings_stars').hover(
            // Handles the mouseover
            function() {
            	$(this).prevAll().andSelf().addClass('ratings_over');
                $(this).nextAll().removeClass('ratings_vote'); 
                	
            },
            
            // Handles the mouseout
            function() {
            	$(this).prevAll().andSelf().removeClass('ratings_over');
            }
        );
    	
    }
    
    function set_totalAvgRating(widget, data) {
    	var exact = data.total_avg;
        var votes = data.reviews;
        
        log('journey_id: ' + data.journey_id);
           	
    	$('.rating_' + data.journey_id + '.rate_widget .total_votes').each(function() {
			$(this).text('Score from ' + votes + ' reviews: ' + exact);
		});
		
    }
        
    function set_votes(widget,data) {
		var avg = parseInt(data.voting);
        var votes = data.number_votes;
        var exact = data.dec_avg;
		var voting = data.voting;
		log('avg: ' + avg);
		log('journey_id: ' + data.journey_id);
				
		$('.rating_' + data.journey_id + '.rate_widget .total_votes').each(function() {
			$(this).text('Score from ' + votes + ' reviews: ' + exact);
		});
	
		for (var i = 1; i <= avg; i++) {
			$('.rating_' + data.journey_id + '.rate_widget .star_' + i).addClass('ratings_vote');
		}
		 
    }
    
    function log(msg) {
    	if (typeof console !== "undefined" && typeof console.log !== "undefined") {
    		console.log(msg);
    	}
    }
    
    
   