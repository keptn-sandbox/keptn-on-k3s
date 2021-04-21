jQuery(document).ready(function(event) { window.setInterval('rotate()', 8000); });

var headerImages = new Array('img/header2.jpg', 'img/header3.jpg', 'img/header4.jpg', 'img/header5.jpg', 'img/header6.jpg', 'img/header7.jpg', 'img/header1.png')

var headerImageCnt = 0;


function rotate() {
	var src = headerImages[headerImageCnt];
	headerImageCnt = headerImageCnt + 1;
	if (headerImageCnt == headerImages.length) {
		headerImageCnt = 0;
	}
	var hdrImg = jQuery('#iceform\\:headerImg');
	var imgHolder = jQuery('.orangeImage.headerImgHolder');
	imgHolder.css('background-image', 'url(../' + hdrImg.attr('src') + ')');
	hdrImg.css('opacity', 0);
	var img = new Image();
	$(img).attr('src', src);
	$(img).load(function() {
		hdrImg.attr('src', src);
		hdrImg.animate({opacity: 1}, 2000);
	});
}